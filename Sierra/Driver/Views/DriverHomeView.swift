import SwiftUI

/// Driver home screen.
/// Availability toggle rules:
///   • Going Available  → always allowed
///   • Going Unavailable → BLOCKED if driver has an active trip OR a trip
///     starts within 30 minutes; ALLOWED otherwise.
/// Error handling: partial load failures show a dismissible inline banner,
/// never a full-screen block. The main content renders regardless.
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

    private var user: AuthUser? { AuthManager.shared.currentUser }

    private var driverMember: StaffMember? {
        guard let userId = user?.id else { return nil }
        return store.staff.first { $0.id == userId }
    }

    private var driverTrips: [Trip] {
        guard let id = driverMember?.id else { return [] }
        return store.trips(forDriver: id).sorted { $0.scheduledDate > $1.scheduledDate }
    }

    private var upcomingTrips: [Trip] {
        driverTrips
            .filter { $0.status == .scheduled || $0.status == .active || $0.status == .accepted || $0.status == .pendingAcceptance }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var recentTrips: [Trip] { Array(driverTrips.prefix(5)) }

    private var isAvailable: Bool { driverMember?.availability == .available }
    private var driverStaffId: UUID? { driverMember?.id }

    private var currentTrip: Trip? {
        guard let member = driverMember else { return nil }
        return store.activeTrip(forDriverId: member.id)
    }

    // 30-minute window check — mirrors the DB function driver_availability_blocked()
    private var tripStartsWithin30Min: Bool {
        let cutoff = Date().addingTimeInterval(30 * 60)
        return driverTrips.contains { trip in
            (trip.status == .scheduled || trip.status == .accepted || trip.status == .pendingAcceptance)
            && trip.scheduledDate <= cutoff
        }
    }

    private var availabilityBinding: Binding<Bool> {
        Binding(
            get: { availabilitySwitch },
            set: { newValue in requestAvailabilityChange(newValue) }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.97, green: 0.97, blue: 0.96).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection

                    VStack(spacing: 16) {
                        // Inline load-error banner (dismissible, non-blocking)
                        if showLoadErrorBanner, let err = store.loadError {
                            loadErrorBanner(err)
                                .padding(.top, 12)
                        }

                        // Loading skeleton
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
                                recentTripsSection
                                recentTripCards
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)

            if showToast, let message = toastMessage {
                availabilityToast(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            availabilitySwitch = isAvailable
            // Show load error banner if there was a partial failure
            if store.loadError != nil { showLoadErrorBanner = true }
        }
        .onChange(of: isAvailable) { _, newValue in availabilitySwitch = newValue }
        .onChange(of: store.loadError) { _, err in
            if err != nil { showLoadErrorBanner = true }
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
                colors: [Color.white.opacity(0.25), .clear],
                center: .topLeading,
                startRadius: 20, endRadius: 320
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
                    HStack(spacing: 10) {
                        Circle()
                            .fill(availabilitySwitch ? Color.green : Color.gray.opacity(0.8))
                            .frame(width: 10, height: 10)
                        Toggle("", isOn: availabilityBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(.green)
                            .scaleEffect(0.86)
                            .disabled(isUpdatingAvailability)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Text(timeOfDayGreeting)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(0.5)

                Text(headerName.uppercased())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(1.2)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 50)
            }
        }
        .frame(height: 230)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 34,
                bottomTrailingRadius: 34, topTrailingRadius: 0, style: .continuous
            )
        )
    }

    // MARK: - Inline Load-Error Banner

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
                Circle().fill(Color(red: 0.11, green: 0.12, blue: 0.16)).frame(width: 44, height: 44)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .rotationEffect(.degrees(45))
            }
            Text("See your current route")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .bold)).foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 1.00, green: 0.84, blue: 0.62).opacity(0.28)))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.42), lineWidth: 1))
    }

    // MARK: - Upcoming Card

    private var upcomingRidesCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(upcomingTrips.count) upcoming Rides")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                    Text(nextRideHeadline)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.94)).frame(width: 84, height: 70)
                    Image(systemName: "car.fill").font(.system(size: 32))
                        .foregroundStyle(Color.secondary.opacity(0.55))
                }
            }
            .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 16)

            Button { tabSelection = .trips } label: {
                Text("View Rides")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(Color(red: 0.11, green: 0.12, blue: 0.16)))
            }
            .padding(.horizontal, 22).padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color(red: 0.92, green: 0.92, blue: 0.93).opacity(0.6), lineWidth: 1))
    }

    // MARK: - Recent Trips

    private var recentTripsSection: some View {
        HStack {
            Text("Recent Trips")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
            Spacer()
            Button { tabSelection = .trips } label: {
                Text("View All")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.orange)
            }
        }
        .padding(.top, 8)
    }

    private var recentTripCards: some View {
        VStack(spacing: 12) {
            ForEach(displayTrips.prefix(3)) { trip in recentTripCard(trip) }
        }
    }

    private func recentTripCard(_ trip: Trip) -> some View {
        NavigationLink(value: trip.id) {
            VStack(alignment: .leading, spacing: 12) {
                Text(trip.taskId)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.orange.opacity(0.10)))

                HStack(spacing: 8) {
                    Text(trip.origin.uppercased())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
                    HStack(spacing: 4) {
                        Rectangle().fill(Color.orange.opacity(0.4)).frame(width: 16, height: 2)
                        Image(systemName: "arrowtriangle.right.fill").font(.system(size: 8)).foregroundStyle(Color.orange)
                        Rectangle().fill(Color.orange.opacity(0.4)).frame(width: 16, height: 2)
                    }
                    Text(trip.destination.uppercased())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
                    Spacer(minLength: 0)
                }

                if let vehicle = vehicleForTrip(trip) {
                    HStack(spacing: 8) {
                        Image(systemName: "car.fill").font(.system(size: 13)).foregroundStyle(Color.secondary)
                        Text(vehicle.licensePlate)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange.opacity(0.08)))
                        Text("\(vehicle.name) \(vehicle.model)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "clock").font(.system(size: 13)).foregroundStyle(Color.secondary)
                    Text(trip.scheduledDate.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }

                Text("View Details")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.orange)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Capsule().fill(Color.orange.opacity(0.12)))
                    .overlay(Capsule().stroke(Color.orange.opacity(0.2), lineWidth: 1))
                    .padding(.top, 4)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 10, y: 4))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.92, green: 0.92, blue: 0.93).opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
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
                Color(red: 1.00, green: 0.79, blue: 0.33),
                Color(red: 0.96, green: 0.54, blue: 0.10),
                Color(red: 0.92, green: 0.35, blue: 0.08)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var displayTrips: [Trip] {
        if let currentTrip {
            var seen = Set<UUID>()
            return ([currentTrip] + recentTrips).filter { seen.insert($0.id).inserted }
        }
        return recentTrips
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

    private func vehicleForTrip(_ trip: Trip) -> Vehicle? {
        guard let vId = trip.vehicleId, let vUUID = UUID(uuidString: vId) else { return nil }
        return store.vehicle(for: vUUID)
    }

    private func availabilityToast(message: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(toastIsError ? Color.red.opacity(0.85)
                      : (availabilitySwitch ? Color.green : Color(red: 0.35, green: 0.35, blue: 0.40)))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                if !toastIsError {
                    Text(availabilitySwitch ? "Ready to accept rides" : "You won\u{2019}t receive new rides")
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(
            Capsule()
                .fill(toastIsError ? Color.red.opacity(0.9)
                      : (availabilitySwitch ? Color.green.opacity(0.9) : Color(red: 0.35, green: 0.35, blue: 0.40)))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        )
        .padding(.horizontal, 20).padding(.top, 58)
    }

    // MARK: - Availability Change Logic

    private func requestAvailabilityChange(_ available: Bool) {
        guard !isUpdatingAvailability else { return }

        // --- Pre-flight: block going Unavailable if within 30-min window or on active trip ---
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
        availabilitySwitch = available // optimistic update

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
                // Force-refresh to get the authoritative value from DB
                await store.loadDriverData(driverId: id)
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
