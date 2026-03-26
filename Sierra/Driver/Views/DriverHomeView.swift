import SwiftUI

/// Driver home screen — exact FMS_SS HomeView.
/// Availability toggle, profile button, current route banner,
/// upcoming rides card, recent trips with AllTripCard dual-button layout.
struct DriverHomeView: View {

    @Environment(AppDataStore.self) private var store
    @Binding var tabSelection: DriverTab

    @State private var showToast = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var availabilitySwitch = false
    @State private var isUpdatingAvailability = false
    @State private var showProfile = false
    @State private var showLoadErrorBanner = false
    @State private var toastPulseScale: CGFloat = 1.0

    // FMS_SS card action state
    @State private var acceptedTripID: UUID?
    @State private var showAcceptConfetti = false
    @State private var selectedDetailTrip: Trip?
    @State private var isAccepting = false
    @State private var inspectionLaunch: InspectionLaunchContext? = nil
    @State private var showAcceptWarning = false
    @State private var navigationTrip: Trip?

    enum InspectionMode { case pre, post }
    private struct InspectionLaunchContext: Identifiable {
        let id = UUID()
        let trip: Trip
        let vehicleId: UUID
        let driverId: UUID
        let mode: InspectionMode
    }

    private var user: AuthUser? { AuthManager.shared.currentUser }

    private var driverMember: StaffMember? {
        guard let userId = user?.id else { return nil }
        return store.staff.first { $0.id == userId }
    }

    private var driverId: UUID? { driverMember?.id }

    private var driverTrips: [Trip] {
        guard let id = driverMember?.id else { return [] }
        return store.trips(forDriver: id)
    }

    private var upcomingTrips: [Trip] {
        driverTrips
            .filter { $0.status == .scheduled || $0.status == .active || $0.status == .pendingAcceptance }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var recentTrips: [Trip] {
        Array(driverTrips.filter { $0.status != .cancelled && $0.status != .rejected }.prefix(5))
    }

    private var isAvailable: Bool { driverMember?.availability == .available }
    private var driverStaffId: UUID? { driverMember?.id }

    private var currentTrip: Trip? {
        guard let member = driverMember else { return nil }
        return store.activeTrip(forDriverId: member.id)
    }

    private var tripStartsWithin30Min: Bool {
        return driverTrips.contains { trip in
            (trip.status == .scheduled || trip.status == .pendingAcceptance)
            && trip.scheduledDate.timeIntervalSinceNow <= TripConstants.driverBlockWindowSeconds
            && trip.scheduledDate.timeIntervalSinceNow > -3600
        }
    }

    private var availabilityBinding: Binding<Bool> {
        Binding(
            get: { availabilitySwitch },
            set: { newValue in requestAvailabilityChange(newValue) }
        )
    }

    private var displayTrips: [Trip] {
        if let currentTrip {
            var seen = Set<UUID>()
            return ([currentTrip] + recentTrips).filter { seen.insert($0.id).inserted }
        }
        return recentTrips
    }

    var body: some View {
        ZStack {
            Color.appSurface.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection

                    VStack(spacing: 16) {
                        if showLoadErrorBanner, let err = store.loadError {
                            loadErrorBanner(err)
                                .padding(.top, 12)
                        }

                        if store.isLoading {
                            ProgressView("Loading assignments\u{2026}")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 30)
                        } else {
                            currentRouteBanner
                                .padding(.top, -30)

                            upcomingRidesCard

                            if displayTrips.isEmpty {
                                noTripAssignedCard.padding(.top, 4)
                            } else {
                                // Section title
                                HStack {
                                    Text("Recent Trips")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.appTextPrimary)
                                    Spacer()
                                    Button { tabSelection = .trips } label: {
                                        Text("View All")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(.appOrange)
                                    }
                                }
                                .padding(.top, 8)

                                // Trip cards — exact same as Trips tab
                                VStack(spacing: 12) {
                                    ForEach(displayTrips.prefix(3)) { trip in
                                        tripCard(trip)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .refreshable {
                if let id = AuthManager.shared.currentUser?.id {
                    await store.refreshDriverData(driverId: id, force: true)
                }
            }

            // Overlays
            if showAcceptConfetti {
                AcceptSuccessOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .zIndex(200)
            }

            if showAcceptWarning {
                AcceptRequiredOverlay(
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) { showAcceptWarning = false }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .zIndex(250)
            }

            if showToast, let message = toastMessage {
                availabilityToast(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        // Trip Detail Popup Overlay
        .overlay {
            if let trip = selectedDetailTrip {
                let vehicle: Vehicle? = {
                    if let idStr = trip.vehicleId, let uuid = UUID(uuidString: idStr) {
                        return store.vehicle(for: uuid)
                    }
                    return nil
                }()
                TripDetailOverlay(
                    trip: trip,
                    vehicle: vehicle,
                    onDismiss: { dismissDetail() },
                    onStartInspection: { startInspection(for: trip) }
                )
                .transition(.opacity)
                .zIndex(300)
            }
        }
        .fullScreenCover(item: $inspectionLaunch) { launch in
            if launch.mode == .post {
                NavigationStack {
                    PostTripInspectionView(
                        tripId: launch.trip.id,
                        vehicleId: launch.vehicleId,
                        driverId: launch.driverId
                    )
                    .environment(store)
                }
            } else {
                PreTripInspectionView(
                    tripId: launch.trip.id,
                    vehicleId: launch.vehicleId,
                    driverId: launch.driverId,
                    inspectionType: .preTripInspection,
                    onComplete: {
                        inspectionLaunch = nil
                    },
                    onBlockedForVehicle: {
                        inspectionLaunch = nil
                        tabSelection = .trips
                    }
                )
                .environment(store)
            }
        }
        .fullScreenCover(item: $navigationTrip) { nTrip in
            TripNavigationContainerView(trip: nTrip)
                .environment(AppDataStore.shared)
        }
        .onAppear {
            availabilitySwitch = isAvailable
            if store.loadError != nil { showLoadErrorBanner = true }
        }
        .onChange(of: isAvailable) { _, newValue in availabilitySwitch = newValue }
        .onChange(of: store.loadError) { _, err in
            withAnimation(.easeOut(duration: 0.2)) {
                showLoadErrorBanner = (err != nil)
            }
        }
        .sheet(isPresented: $showProfile) {
            DriverProfileSheet()
                .environment(AppDataStore.shared)
                .presentationDetents([.large])
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack {
            headerGradient

            RadialGradient(
                colors: [Color.white.opacity(0.25), Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 300
            )

            RadialGradient(
                colors: [Color.appDeepOrange.opacity(0.4), Color.clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 250
            )

            VStack(spacing: 6) {
                HStack {
                    Button { showProfile = true } label: {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Text(driverMember?.initials ?? "D")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            )
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Circle()
                            .fill(availabilitySwitch ? Color.green : Color.gray)
                            .frame(width: 9, height: 9)
                            .shadow(
                                color: availabilitySwitch ? Color.green.opacity(0.6) : Color.clear,
                                radius: 4
                            )
                            .animation(.easeInOut(duration: 0.3), value: availabilitySwitch)

                        Toggle("", isOn: availabilityBinding)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .labelsHidden()
                            .scaleEffect(0.85)
                            .disabled(isUpdatingAvailability)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Text(timeOfDayGreeting)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(0.5)

                Text(headerName.uppercased())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.2)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                    .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 50)
            }
        }
        .frame(height: 230)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32,
                topTrailingRadius: 0
            )
        )
    }

    // MARK: - Load Error Banner

    private func loadErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Some data failed to load. Pull to refresh.")
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            Button {
                withAnimation { showLoadErrorBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Current Route Banner

    private var currentRouteBanner: some View {
        Group {
            if let trip = currentTrip {
                NavigationLink(value: trip.id) { currentRouteBannerLabel }
                    .buttonStyle(.plain)
            } else {
                currentRouteBannerLabel
            }
        }
    }

    private var currentRouteBannerLabel: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.appTextPrimary)
                    .frame(width: 44, height: 44)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(45))
            }

            Text("See your current route")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.appTextSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
    }

    // MARK: - Upcoming Rides Card

    private var upcomingRidesCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(upcomingTrips.count) upcoming Rides")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)

                    Text(nextRideHeadline)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.appSurface, Color.appDivider],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 80, height: 70)

                    Image(systemName: "bus.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.appTextSecondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 16)

            Button { tabSelection = .trips } label: {
                Text("View Rides")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.appTextPrimary)
                    )
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appCardBg)
                .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.appDivider.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Trip Card (exact same as TripsView AllTripCard)

    private func tripCard(_ trip: Trip) -> some View {
        let isJustAccepted = acceptedTripID == trip.id
        let vehicle: Vehicle? = {
            guard let vIdStr = trip.vehicleId, let vUUID = UUID(uuidString: vIdStr) else { return nil }
            return store.vehicle(for: vUUID)
        }()
        let isWaitingForVehicle = store.isTripWaitingForVehicleReassignment(trip)

        return DriverTripCard(
            trip: trip,
            vehicle: vehicle,
            isWaitingForVehicleReassignment: isWaitingForVehicle,
            isJustAccepted: isJustAccepted,
            isAccepting: isAccepting,
            onAccept: { acceptTrip(trip) },
            onShowTripDetail: { showTripDetail(trip) },
            onNavigate: { navigationTrip = trip },
            onPostTripInspection: { openPostTripInspection(for: trip) }
        )
    }

    // MARK: - Route Row (city name big, rest smaller)

    private func routeRow(origin: String, destination: String) -> some View {
        HStack(spacing: 10) {
            cityLabel(origin)
            RouteArrow()
            cityLabel(destination)
        }
    }

    private func cityLabel(_ text: String) -> some View {
        let words = text.split(separator: " ")
        let city = String(words.first ?? Substring(text))
        let rest = words.dropFirst().joined(separator: " ")

        return VStack(alignment: .leading, spacing: 1) {
            Text(city.uppercased())
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !rest.isEmpty {
                Text(rest)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Vehicle Info

    private func vehicleInfo(_ trip: Trip) -> some View {
        Group {
            if let vIdStr = trip.vehicleId, let vUUID = UUID(uuidString: vIdStr),
               let vehicle = store.vehicle(for: vUUID) {
                HStack(spacing: 8) {
                    Text(vehicle.licensePlate)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.appOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.appOrange.opacity(0.08)))

                    Text("\(vehicle.name) \(vehicle.model)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Action Buttons (exact FMS_SS flow)

    @ViewBuilder
    private func actionButtons(_ trip: Trip) -> some View {
        let status: TripStatus = trip.isDriverWorkflowCompleted ? .completed : trip.status.normalized
        let isCompleted = status == .completed
        let isCancelled = status == .cancelled
        let needsPostTrip = trip.requiresPostTripInspection
        let postTripDone = isCompleted && trip.postInspectionId != nil
        let hasPreInspection = trip.preInspectionId != nil
        let isAcceptedScheduled = status == .scheduled && trip.acceptedAt != nil
        let navProgress = TripNavigationCoordinator.sessionProgress(for: trip.id) ?? 0
        let navigationLockedByProgress = navProgress >= 0.999
        let isReadyToStart = isAcceptedScheduled && hasPreInspection
        if needsPostTrip {
            SlideToStartInspectionButton(
                label: "Post-Trip Inspection",
                controlHeight: 44,
                onComplete: { openPostTripInspection(for: trip) }
            )
        } else if postTripDone {
            HStack(spacing: 12) {
                NavigationLink(value: trip.id) {
                    DriverTripCardActionButton(
                        title: "View Details",
                        icon: "doc.text.magnifyingglass",
                        style: .outlineOrange
                    )
                }
                .buttonStyle(.plain)

                DriverTripCardActionButton(
                    title: "Completed",
                    icon: "checkmark.circle.fill",
                    style: .success
                )
            }
        } else {
            HStack(spacing: 12) {
                // Left: View Details
                if isAcceptedScheduled && !hasPreInspection {
                    DriverTripCardActionButton(
                        title: "View Details",
                        icon: "doc.text.magnifyingglass",
                        style: .outlineOrange,
                        action: { showTripDetail(trip) }
                    )
                } else {
                    NavigationLink(value: trip.id) {
                        DriverTripCardActionButton(
                            title: "View Details",
                            icon: "doc.text.magnifyingglass",
                            style: .outlineOrange
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Right: Accept / Accepted / Navigate
                if isCancelled {
                    DriverTripCardActionButton(
                        title: "Cancelled",
                        icon: "xmark.circle.fill",
                        style: .cancelled
                    )
                } else if status == .pendingAcceptance {
                    DriverTripCardActionButton(
                        title: "Accept Trip",
                        icon: "hand.thumbsup.fill",
                        style: .solidDark,
                        action: { acceptTrip(trip) },
                        isDisabled: isAccepting
                    )
                } else if isAcceptedScheduled && !hasPreInspection {
                    DriverTripCardActionButton(
                        title: "Accepted",
                        icon: "checkmark.seal.fill",
                        style: .success
                    )
                } else if isReadyToStart {
                    DriverTripCardActionButton(
                        title: "Navigate",
                        icon: "location.fill",
                        style: .solidNavigate,
                        action: { navigationTrip = trip }
                    )
                } else if status == .active && !trip.hasEndedNavigationPhase && !navigationLockedByProgress {
                    DriverTripCardActionButton(
                        title: "Navigate",
                        icon: "location.fill",
                        style: .solidNavigate,
                        action: { navigationTrip = trip }
                    )
                } else {
                    DriverTripCardActionButton(
                        title: status.rawValue,
                        icon: "clock.fill",
                        style: .neutral
                    )
                }
            }
        }
    }

    // MARK: - Card Actions

    private func acceptTrip(_ trip: Trip) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            acceptedTripID = trip.id
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showAcceptConfetti = true
        }

        isAccepting = true
        Task {
            do {
                try await store.acceptTrip(tripId: trip.id)
            } catch {
                print("[DriverHomeView] Accept failed: \(error)")
            }
            isAccepting = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showAcceptConfetti = false
                acceptedTripID = nil
            }
        }
    }

    private func showTripDetail(_ trip: Trip) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            selectedDetailTrip = trip
        }
    }

    private func dismissDetail() {
        withAnimation(.easeOut(duration: 0.25)) {
            selectedDetailTrip = nil
        }
    }

    private func openPostTripInspection(for trip: Trip) {
        guard trip.requiresPostTripInspection else { return }
        presentInspection(for: trip, mode: .post)
    }

    private func startInspection(for trip: Trip) {
        let status = trip.status.normalized
        if status == .scheduled && trip.acceptedAt != nil && trip.preInspectionId == nil {
            presentInspection(for: trip, mode: .pre)
        } else if status == .completed && trip.postInspectionId == nil {
            presentInspection(for: trip, mode: .post)
        } else if status == .pendingAcceptance || (status == .scheduled && trip.acceptedAt == nil && trip.preInspectionId == nil) {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            dismissDetail()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showAcceptWarning = true }
        }
    }

    private func presentInspection(for trip: Trip, mode: InspectionMode) {
        func parseUUID(_ text: String?) -> UUID? {
            guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
            let cleaned = raw.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
            return UUID(uuidString: cleaned)
        }

        guard !trip.taskId.isEmpty else { return }

        let latestTrip = store.trips.first(where: { $0.id == trip.id }) ?? trip

        func resolvedContext(from baseTrip: Trip) -> (trip: Trip, vehicleId: UUID, driverId: UUID)? {
            let latest = store.trips.first(where: { $0.id == baseTrip.id }) ?? baseTrip
            guard let vehicleUUID = parseUUID(latest.vehicleId ?? baseTrip.vehicleId) else { return nil }
            guard let resolvedDriver = driverId
                ?? AuthManager.shared.currentUser?.id
                ?? parseUUID(latest.driverId ?? baseTrip.driverId) else { return nil }
            return (trip: latest, vehicleId: vehicleUUID, driverId: resolvedDriver)
        }

        if let context = resolvedContext(from: latestTrip) {
            dismissDetail()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                inspectionLaunch = InspectionLaunchContext(
                    trip: context.trip,
                    vehicleId: context.vehicleId,
                    driverId: context.driverId,
                    mode: mode
                )
            }
            return
        }

        Task {
            guard let currentDriverId = AuthManager.shared.currentUser?.id else { return }
            await store.refreshDriverData(driverId: currentDriverId, force: true)
            guard let context = resolvedContext(from: latestTrip) else { return }
            await MainActor.run {
                dismissDetail()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    inspectionLaunch = InspectionLaunchContext(
                        trip: context.trip,
                        vehicleId: context.vehicleId,
                        driverId: context.driverId,
                        mode: mode
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    private var noTripAssignedCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "mappin.slash").font(.system(size: 50))
                .foregroundStyle(.gray.opacity(0.5)).padding(.top, 20)
            Text("No Trip Assigned").font(.headline).foregroundStyle(.secondary)
            Text("Your Fleet Manager hasn\u{2019}t assigned a delivery task yet.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(2)

            if availabilitySwitch {
                Text("You\u{2019}re available — awaiting dispatch")
                    .font(.caption.weight(.medium)).foregroundStyle(Color(.systemGreen))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(.systemGreen).opacity(0.1), in: Capsule())
            } else {
                VStack(spacing: 10) {
                    Text("Set yourself as Available to receive trips")
                        .font(.caption.weight(.medium)).foregroundStyle(Color(.systemOrange))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color(.systemOrange).opacity(0.1), in: Capsule())
                    Button { requestAvailabilityChange(true) } label: {
                        Text("Set Available")
                            .font(.caption).foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(.orange, in: Capsule())
                    }
                    .disabled(isUpdatingAvailability)
                }
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Helpers

    private var headerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.appAmber,
                Color.appOrange,
                Color.appDeepOrange.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var headerName: String {
        driverMember?.displayName ?? user?.name ?? "Driver"
    }

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default:      return "Good Night"
        }
    }

    private var nextRideHeadline: String {
        guard let nextTrip = upcomingTrips.first else { return "No upcoming rides" }
        if nextTrip.status == .active { return "Ride in progress" }
        let interval = nextTrip.scheduledDate.timeIntervalSinceNow
        if interval <= 0 { return "Starting soon" }
        let mins = Int(interval / 60)
        if mins < 60 { return "First Ride in \(mins) min" }
        return "First Ride in \(max(1, mins / 60)) hr"
    }

    private func availabilityToast(message: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(toastIsError ? Color.red.opacity(0.25)
                          : (availabilitySwitch ? Color.green.opacity(0.25) : Color.red.opacity(0.25)))
                    .frame(width: 28, height: 28)
                    .scaleEffect(toastPulseScale)

                Circle()
                    .fill(toastIsError ? Color.red
                          : (availabilitySwitch ? Color.green : Color.red.opacity(0.8)))
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if !toastIsError {
                    Text(availabilitySwitch ? "Ready to accept rides" : "You won\u{2019}t receive new rides")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
            }

            Spacer()

            Image(systemName: toastIsError ? "xmark.circle.fill"
                  : (availabilitySwitch ? "checkmark.circle.fill" : "moon.fill"))
                .font(.system(size: 22))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(
                    toastIsError
                        ? Color.red.opacity(0.9)
                        : (availabilitySwitch
                            ? Color.green.opacity(0.9)
                            : Color(red: 0.35, green: 0.35, blue: 0.40))
                )
                .shadow(
                    color: (toastIsError ? Color.red
                            : (availabilitySwitch ? Color.green : Color.black)).opacity(0.3),
                    radius: 16, x: 0, y: 6
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatCount(3, autoreverses: true)
            ) {
                toastPulseScale = 1.5
            }
        }
        .onDisappear {
            toastPulseScale = 1.0
        }
    }

    // MARK: - Availability Change Logic

    private func requestAvailabilityChange(_ available: Bool) {
        guard !isUpdatingAvailability else { return }

        if !available {
            if let trip = currentTrip, trip.status == .active {
                presentToast("You\u{2019}re on an active trip", isError: true)
                return
            }
            if tripStartsWithin30Min {
                presentToast("Trip starts in under 30 min — you can\u{2019}t go offline now", isError: true)
                return
            }
        }

        let previous = availabilitySwitch
        availabilitySwitch = available

        Task {
            let ok = await persistAvailability(available)
            if !ok { await MainActor.run { availabilitySwitch = previous } }
        }
    }

    private func persistAvailability(_ available: Bool) async -> Bool {
        if isAvailable == available { return true }
        guard let id = driverStaffId else {
            presentToast("Could not update — missing driver ID", isError: true)
            return false
        }

        await MainActor.run { isUpdatingAvailability = true }
        do {
            try await store.updateDriverAvailability(staffId: id, available: available)
            let expected: StaffAvailability = available ? .available : .unavailable
            let confirmed = store.staff.first(where: { $0.id == id })?.availability == expected
            if !confirmed {
                await store.refreshDriverData(driverId: id, force: true)
            }
            await MainActor.run {
                isUpdatingAvailability = false
                presentToast(available ? "You\u{2019}re Available" : "You\u{2019}re Offline", isError: false)
            }
            return true
        } catch {
            await MainActor.run {
                isUpdatingAvailability = false
                presentToast("Update failed: \(error.localizedDescription)", isError: true)
            }
            return false
        }
    }

    @MainActor
    private func presentToast(_ message: String, isError: Bool) {
        toastMessage  = message
        toastIsError  = isError
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { showToast = true }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.35)) { showToast = false }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DriverHomeView(tabSelection: .constant(.home))
            .environment(AppDataStore.shared)
    }
}
