import SwiftUI
import MapKit

/// Driver-side trip list — FMS_SS TripsView flow.
/// State machine for action buttons:
///   PendingAcceptance → Accept Trip
///   Scheduled + no preInspection → Do Inspection (opens overlay with slider)
///   Scheduled + preInspection done + NOT within 30-min window → "Starts HH:MM" (disabled)
///   Scheduled + preInspection done + within 30-min window → Start Trip (NavigationLink → TripDetailDriverView)
///   Active → Navigate (direct navigation)
///   Completed + no postInspection → SlideToStartInspectionButton
///   Completed + postInspection done → CompletedInspectionButton
struct DriverTripsListView: View {

    @Environment(AppDataStore.self) private var store
    @State private var searchText = ""
    @State private var selectedStatus: TripStatus? = nil
    @State private var hasAppeared = false

    // FMS_SS overlay state
    @State private var showAcceptConfetti = false
    @State private var acceptedTripID: UUID? = nil
    @State private var showAcceptWarning = false
    @State private var showWaitingVehicleOverlay = false
    @State private var selectedDetailTrip: Trip? = nil
    @State private var showInspection = false
    @State private var inspectionTrip: Trip? = nil
    @State private var inspectionMode: InspectionFlowMode = .pre
    @State private var isAccepting = false
    @State private var navigationTrip: Trip? = nil

    enum InspectionFlowMode { case pre, post }

    private var driverId: UUID? { AuthManager.shared.currentUser?.id }

    private var driverTrips: [Trip] {
        guard let id = driverId else { return [] }
        return store.trips(forDriver: id)
    }

    private var filtered: [Trip] {
        driverTrips
            .filter { trip in
                // Bug 4: gate Completed filter on postInspectionId
                if let s = selectedStatus {
                    let normalised: TripStatus = trip.isDriverWorkflowCompleted ? .completed : trip.status.normalized
                    if s == .completed {
                        guard normalised == .completed && trip.postInspectionId != nil else { return false }
                    } else {
                        guard normalised == s.normalized else { return false }
                    }
                }
                if !searchText.isEmpty {
                    let q = searchText.lowercased()
                    return trip.taskId.lowercased().contains(q)
                        || trip.origin.lowercased().contains(q)
                        || trip.destination.lowercased().contains(q)
                }
                return true
            }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    private var isFilterActive: Bool { selectedStatus != nil }

    // MARK: - Stats

    private var totalCount: Int    { driverTrips.count }
    private var urgentCount: Int   { driverTrips.filter { $0.priority == .urgent }.count }
    // Bug 7: count only accepted (scheduled + acceptedAt set) trips
    private var acceptedCount: Int { driverTrips.filter { $0.status == .scheduled && $0.acceptedAt != nil }.count }

    var body: some View {
        ZStack {
            Color.appSurface.ignoresSafeArea()

            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        HStack {
                            Text("All Trips")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.appTextPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                        statsBar
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : -20)

                        if let status = selectedStatus {
                            filterBanner(status)
                                .padding(.horizontal, 20)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        LazyVStack(spacing: 14) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, trip in
                                tripCard(trip)
                                    .opacity(hasAppeared ? 1 : 0)
                                    .offset(y: hasAppeared ? 0 : 30)
                                    .animation(
                                        .spring(response: 0.6, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.08 + 0.2),
                                        value: hasAppeared
                                    )
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                                        removal: .scale(scale: 0.9).combined(with: .opacity)
                                    ))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 8)
                }
            }

            // Accept success overlay
            if showAcceptConfetti {
                AcceptSuccessOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .zIndex(200)
            }

            // Accept required overlay
            if showAcceptWarning {
                AcceptRequiredOverlay(
                    onAccept: {
                        withAnimation(.easeOut(duration: 0.25)) { showAcceptWarning = false }
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) { showAcceptWarning = false }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .zIndex(250)
            }

            if showWaitingVehicleOverlay {
                WaitingVehicleOverlay(onDismiss: {
                    withAnimation(.easeOut(duration: 0.25)) { showWaitingVehicleOverlay = false }
                })
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .zIndex(260)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search task ID, origin…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Filter by Status") {
                        Button {
                            withAnimation(.spring(response: 0.4)) { selectedStatus = nil }
                        } label: {
                            Label("All Trips", systemImage: selectedStatus == nil ? "checkmark.circle.fill" : "square.grid.2x2")
                        }
                        // Only show canonical statuses in filter
                        ForEach([TripStatus.pendingAcceptance, .scheduled, .active, .completed, .cancelled], id: \.self) { status in
                            Button {
                                withAnimation(.spring(response: 0.4)) { selectedStatus = status }
                            } label: {
                                Label(statusDisplayName(status), systemImage: selectedStatus == status ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                    if isFilterActive {
                        Divider()
                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.4)) { selectedStatus = nil }
                        } label: {
                            Label("Clear Filters", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isFilterActive ? Color.appOrange.opacity(0.12) : Color.clear)
                            .frame(width: 36, height: 36)
                        Image(systemName: isFilterActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color.appOrange)
                    }
                }
            }
        }
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
        .fullScreenCover(isPresented: $showInspection) {
            Group {
                if let iTrip = inspectionTrip,
                   let vIdStr = iTrip.vehicleId,
                   let vehicleUUID = UUID(uuidString: vIdStr),
                   let dId = driverId {
                    if inspectionMode == .post {
                        NavigationStack {
                            PostTripInspectionView(
                                tripId: iTrip.id, vehicleId: vehicleUUID, driverId: dId
                            )
                            .environment(store)
                        }
                    } else {
                        PreTripInspectionView(
                            tripId: iTrip.id, vehicleId: vehicleUUID, driverId: dId,
                            inspectionType: .preTripInspection,
                            onComplete: {
                                showInspection = false
                                inspectionTrip = nil
                            }
                        )
                        .environment(store)
                    }
                } else {
                    VStack(spacing: 14) {
                        Text("Inspection screen unavailable")
                            .font(.headline)
                        Text("Trip or vehicle data is missing. Please reopen from the trip card.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Close") {
                            showInspection = false
                            inspectionTrip = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                }
            }
        }
        .fullScreenCover(item: $navigationTrip) { nTrip in
            TripNavigationContainerView(trip: nTrip)
                .environment(AppDataStore.shared)
        }
        .task {
            if store.trips.isEmpty, let id = driverId {
                await store.loadDriverData(driverId: id)
            }
        }
        .refreshable {
            if let id = driverId { await store.loadDriverData(driverId: id) }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Actions

    private func acceptTrip(_ trip: Trip) {
        guard !isAccepting else { return }
        isAccepting = true

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Optimistic UI
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showAcceptConfetti = true
            acceptedTripID = trip.id
        }

        Task {
            do {
                try await store.acceptTrip(tripId: trip.id)
            } catch {
                // Revert optimistic UI on failure
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showAcceptConfetti = false
                        acceptedTripID = nil
                    }
                }
                print("[DriverTripsListView] Accept failed: \(error.localizedDescription)")
            }
            await MainActor.run { isAccepting = false }
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
        withAnimation(.easeOut(duration: 0.25)) { selectedDetailTrip = nil }
    }

    private func openPostTripInspection(for trip: Trip) {
        guard trip.requiresPostTripInspection else { return }
        inspectionMode = .post
        inspectionTrip = trip
        dismissDetail()
        showInspection = true
    }

    private func startInspection(for trip: Trip) {
        // Pre-trip: only when Scheduled (driver accepted) + inspection not yet done
        if trip.status == .scheduled && trip.preInspectionId == nil {
            inspectionMode = .pre
            inspectionTrip = trip
            dismissDetail()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showInspection = true }
        }
        // Post-trip: required after completed or ended-navigation phase
        else if trip.requiresPostTripInspection {
            inspectionMode = .post
            inspectionTrip = trip
            dismissDetail()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showInspection = true }
        }
        // PendingAcceptance: prompt to accept first
        else if trip.status == .pendingAcceptance {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            dismissDetail()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showAcceptWarning = true }
        }
        // else: pre-inspection already done, or active — no action needed
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(value: "\(totalCount)", label: "Total", icon: "list.bullet", color: Color.appOrange)
            Divider().frame(height: 32).padding(.horizontal, 4)
            statItem(value: "\(urgentCount)", label: "Urgent", icon: "flame.fill", color: Color(red: 0.85, green: 0.18, blue: 0.15))
            Divider().frame(height: 32).padding(.horizontal, 4)
            // Bug 7: label is "Accepted", counts scheduled+accepted trips only
            statItem(value: "\(acceptedCount)", label: "Accepted", icon: "checkmark.seal.fill", color: Color(red: 0.20, green: 0.65, blue: 0.32))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appCardBg)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider.opacity(0.5), lineWidth: 1))
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundColor(color)
                Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.appTextPrimary)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextSecondary)
                .textCase(.uppercase).tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private func filterBanner(_ status: TripStatus) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(statusColor(status))
            Text("Showing: \(statusDisplayName(status))")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3)) { selectedStatus = nil }
            } label: {
                HStack(spacing: 4) {
                    Text("Clear").font(.system(size: 13, weight: .bold, design: .rounded))
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                }
                .foregroundColor(Color.appOrange)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 14).fill(statusColor(status).opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(statusColor(status).opacity(0.35), lineWidth: 1))
    }

    // MARK: - Trip Card

    private func tripCard(_ trip: Trip) -> some View {
        let isJustAccepted = acceptedTripID == trip.id

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "bus.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
                Text(trip.taskId)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.appOrange)
                Spacer()
                if trip.isDriverWorkflowCompleted {
                    completedBadge
                } else {
                    priorityBadge(trip.priority)
                }
            }

            HStack(spacing: 10) {
                cityLabel(trip.origin)
                RouteArrow()
                cityLabel(trip.destination)
            }

            vehicleInfo(trip)

            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock").font(.system(size: 13)).foregroundColor(.appTextSecondary)
                Text(trip.scheduledDate.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
            }

            if trip.status == .pendingAcceptance, let deadline = trip.acceptanceDeadline {
                deadlineBadge(deadline: deadline)
            }

            Rectangle().fill(Color.appDivider).frame(height: 1).padding(.vertical, 2)

            actionButtons(trip)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(color: trip.priority.color.opacity(0.10), radius: 14, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    isJustAccepted
                        ? Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.5)
                        : trip.priority.color.opacity(0.22),
                    lineWidth: isJustAccepted ? 2 : 1
                )
        )
        .scaleEffect(isJustAccepted ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isJustAccepted)
    }

    // MARK: - Action Buttons
    // State machine:
    //   PendingAcceptance → Accept Trip
    //   Scheduled + no preInspection → "Inspect Vehicle" (orange, opens overlay with pre-trip slider)
    //   Scheduled + preInspection done + NOT within window → "Starts HH:MM" (disabled gray)
    //   Scheduled + preInspection done + within 30-min window → NavigationLink "Start Trip" (red)
    //   Active → "Navigate" (red, opens navigation directly)
    //   Completed + no postInspection → SlideToStartInspectionButton
    //   Completed + postInspection done → CompletedInspectionButton

    @ViewBuilder
    private func actionButtons(_ trip: Trip) -> some View {
        let status: TripStatus = trip.isDriverWorkflowCompleted ? .completed : trip.status.normalized
        let isCompleted     = status == .completed
        let isCancelled     = status == .cancelled
        let needsPostTrip   = trip.requiresPostTripInspection
        let postTripDone    = isCompleted && trip.postInspectionId != nil
        let hasPreInspection = trip.preInspectionId != nil
        let navProgress = TripNavigationCoordinator.sessionProgress(for: trip.id) ?? 0
        let navigationLockedByProgress = navProgress >= 0.999
        // isAcceptedScheduled: driver has accepted (acceptedAt set) → status is Scheduled
        let isAcceptedScheduled = status == .scheduled && trip.acceptedAt != nil
        let isReadyToStart  = isAcceptedScheduled && hasPreInspection
        if needsPostTrip {
            SlideToStartInspectionButton(
                label: "Post-Trip Inspection",
                controlHeight: 44,
                onComplete: { openPostTripInspection(for: trip) }
            )
        } else if postTripDone {
            HStack(spacing: 12) {
                NavigationLink(value: trip.id) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass").font(.system(size: 13, weight: .semibold))
                        Text("View Details").font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.appOrange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.appOrange.opacity(0.08)))
                    .overlay(Capsule().stroke(Color.appOrange.opacity(0.25), lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13, weight: .semibold))
                    Text("Completed").font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12)))
                .overlay(Capsule().stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.3), lineWidth: 1.5))
            }
        } else {
            HStack(spacing: 12) {
                // Left: always "View Details" (opens TripDetailOverlay)
                if isAcceptedScheduled && !hasPreInspection {
                    Button {
                        showTripDetail(trip)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 13, weight: .semibold))
                            Text("View Details").font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color.appOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.appOrange.opacity(0.08)))
                        .overlay(Capsule().stroke(Color.appOrange.opacity(0.25), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(value: trip.id) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 13, weight: .semibold))
                            Text("View Details").font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color.appOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.appOrange.opacity(0.08)))
                        .overlay(Capsule().stroke(Color.appOrange.opacity(0.25), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }

                // Right: varies by state
                if isCancelled {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 13, weight: .semibold))
                        Text("Cancelled").font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(red: 0.90, green: 0.22, blue: 0.18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.appDivider.opacity(0.3)))
                } else if status == .pendingAcceptance {
                    // Accept Trip
                    Button { acceptTrip(trip) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.thumbsup.fill").font(.system(size: 13, weight: .semibold))
                            Text("Accept Trip").font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.appTextPrimary))
                    }
                    .buttonStyle(.plain)
                    .disabled(isAccepting)
                } else if isAcceptedScheduled && !hasPreInspection {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 13, weight: .semibold))
                        Text("Accepted").font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12)))
                    .overlay(Capsule().stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.3), lineWidth: 1.5))
                } else if isReadyToStart {
                    Button {
                        navigationTrip = trip
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill").font(.system(size: 13, weight: .semibold))
                            Text("Start Navigation").font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32)))
                    }
                    .buttonStyle(.plain)
                } else if status == .active && !trip.hasEndedNavigationPhase && !navigationLockedByProgress {
                    // Active → Navigate directly
                    Button {
                        navigationTrip = trip
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill").font(.system(size: 13, weight: .semibold))
                            Text("Start Navigation").font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32)))
                    }
                    .buttonStyle(.plain)
                } else if isCompleted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 13, weight: .semibold))
                        Text("Completed").font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12)))
                    .overlay(Capsule().stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.3), lineWidth: 1.5))
                } else {
                    // Fallback: any other status (cancelled, legacy)
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill").font(.system(size: 13, weight: .semibold))
                        Text(statusDisplayName(status)).font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(.tertiarySystemGroupedBackground)))
                    .overlay(Capsule().stroke(Color.appDivider.opacity(0.6), lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Priority Badge

    private func priorityBadge(_ priority: TripPriority) -> some View {
        PriorityBadge(priority: priority)
    }

    private var completedBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 11, weight: .bold))
            Text("Completed").font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.10)))
        .overlay(Capsule().stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.35), lineWidth: 1.5))
    }

    private func cityLabel(_ text: String) -> some View {
        let words = text.split(separator: " ")
        let city = String(words.first ?? Substring(text))
        let rest = words.dropFirst().joined(separator: " ")
        return VStack(alignment: .leading, spacing: 1) {
            Text(city.uppercased())
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary).lineLimit(1).minimumScaleFactor(0.7)
            if !rest.isEmpty {
                Text(rest)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary).lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func vehicleInfo(_ trip: Trip) -> some View {
        if let idStr = trip.vehicleId, let uuid = UUID(uuidString: idStr),
           let v = store.vehicle(for: uuid) {
            HStack(spacing: 8) {
                Text(v.licensePlate)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.appOrange)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.appOrange.opacity(0.08)))
                Text("\(v.name) \(v.model)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary).lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func deadlineBadge(deadline: Date) -> some View {
        let isOverdue = deadline < Date()
        let isUrgent  = deadline < Date().addingTimeInterval(2 * 3600) && !isOverdue
        HStack(spacing: 6) {
            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isOverdue ? .red : Color.appOrange)
            Text(isOverdue
                 ? "Response Overdue"
                 : "Respond by \(deadline.formatted(.dateTime.hour().minute()))")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(isOverdue ? .red : Color.appOrange)
            Spacer()
            if isUrgent {
                Text("< 2h left")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.appOrange))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill((isOverdue ? Color.red : Color.appOrange).opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke((isOverdue ? Color.red : Color.appOrange).opacity(0.2), lineWidth: 1))
    }

    private var emptyState: some View {
        AppEmptyStateCard(
            title: "No Trips Found",
            subtitle: searchText.isEmpty
                ? "You haven\u{2019}t been assigned any trips yet."
                : "Try a different search term.",
            actionTitle: "Refresh",
            action: {
                Task { if let id = driverId { await store.loadDriverData(driverId: id) } }
            }
        )
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusDisplayName(_ status: TripStatus) -> String {
        switch status {
        case .pendingAcceptance: return "Pending Acceptance"
        case .scheduled:         return "Scheduled"
        case .active:            return "Active"
        case .completed:         return "Completed"
        case .cancelled:         return "Cancelled"
        case .accepted:          return "Scheduled"
        case .rejected:          return "Cancelled"
        }
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .active:               return Color(red: 0.20, green: 0.65, blue: 0.32)
        case .scheduled:            return .blue
        case .pendingAcceptance:    return Color.appOrange
        case .completed:            return .appTextSecondary
        case .rejected, .cancelled: return Color(red: 0.90, green: 0.22, blue: 0.18)
        case .accepted:             return .blue
        }
    }
}

// MARK: - Priority Badge (reusable)
struct PriorityBadge: View {
    let priority: TripPriority
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 5) {
            if priority == .urgent {
                Circle()
                    .fill(priority.color)
                    .frame(width: 7, height: 7)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                    .onAppear { isPulsing = true }
            }
            Text(priority.rawValue)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(priority.color)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(priority.bgColor))
        .overlay(Capsule().stroke(priority.borderColor, lineWidth: 1.5))
    }
}

// MARK: - Route Arrow (animated dashes)
struct RouteArrow: View {
    @State private var dashOffset: CGFloat = 0
    var body: some View {
        HStack(spacing: 0) {
            RouteLine()
                .stroke(Color.appOrange.opacity(0.5),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 4], dashPhase: dashOffset))
                .frame(width: 30, height: 2)
            Image(systemName: "arrowtriangle.right.fill").font(.system(size: 9)).foregroundColor(Color.appOrange)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                dashOffset = -18
            }
        }
    }
}

struct RouteLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - Accept Success Overlay
struct AcceptSuccessOverlay: View {
    @State private var scale: CGFloat = 0.5
    @State private var checkOpacity: Double = 0
    var body: some View {
        // Full-screen container so the card is centred on whatever screen it appears on
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.15))
                        .frame(width: 110, height: 110)
                        .scaleEffect(scale > 0.8 ? 1.3 : 0.8)
                    Circle()
                        .fill(Color(red: 0.20, green: 0.65, blue: 0.32))
                        .frame(width: 80, height: 80)
                        .shadow(color: Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.4), radius: 20)
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(checkOpacity)
                        .scaleEffect(checkOpacity > 0 ? 1.0 : 0.3)
                }
                Text("Trip Accepted!")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .opacity(checkOpacity)
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 32).fill(.ultraThinMaterial).shadow(color: Color.black.opacity(0.1), radius: 30))
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { scale = 1.0 }
                withAnimation(.easeOut(duration: 0.3).delay(0.25)) { checkOpacity = 1.0 }
            }
        }
    }
}

struct CompletedBadge: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 11, weight: .bold))
            Text("Completed").font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.10)))
        .overlay(Capsule().stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.35), lineWidth: 1.5))
    }
}

// MARK: - Trip Detail Overlay
struct TripDetailOverlay: View {
    let trip: Trip
    let vehicle: Vehicle?
    let onDismiss: () -> Void
    let onStartInspection: () -> Void
    @State private var cardScale: CGFloat = 0.85
    @State private var cardOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { onDismiss() }
            TripDetailCard(trip: trip, vehicle: vehicle, onStartInspection: onStartInspection)
                .padding(.horizontal, 28)
                .scaleEffect(cardScale)
                .opacity(cardOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
    }
}

// MARK: - Route Preview Map (MKMapView with driving polyline)
struct RoutePreviewMap: UIViewRepresentable {
    let originLat: Double?
    let originLng: Double?
    let destLat:   Double?
    let destLng:   Double?
    let originName: String
    let destName:   String

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isZoomEnabled = false; map.isScrollEnabled = false
        map.isRotateEnabled = false; map.isPitchEnabled = false
        map.isUserInteractionEnabled = false
        map.mapType = .standard; map.delegate = context.coordinator
        map.showsCompass = false; map.showsScale = false
        context.coordinator.map = map
        Task { await loadRoute(map: map) }
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        weak var map: MKMapView?
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)
                renderer.lineWidth = 4.5; renderer.lineCap = .round; renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    @MainActor
    private func loadRoute(map: MKMapView) async {
        let origin: CLLocationCoordinate2D?
        let dest:   CLLocationCoordinate2D?

        if let lat = originLat, let lng = originLng, lat != 0 || lng != 0 {
            origin = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else { origin = await geocode(originName) }

        if let lat = destLat, let lng = destLng, lat != 0 || lng != 0 {
            dest = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else { dest = await geocode(destName) }

        guard let o = origin, let d = dest else { return }

        let originPin = MKPointAnnotation(); originPin.coordinate = o
        let destPin   = MKPointAnnotation(); destPin.coordinate   = d
        map.addAnnotations([originPin, destPin])

        let request = MKDirections.Request()
        request.source      = mapItem(for: o)
        request.destination = mapItem(for: d)
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        do {
            let result = try await MKDirections(request: request).calculate()
            guard let route = result.routes.first else { return }
            map.addOverlay(route.polyline, level: .aboveRoads)
            map.setVisibleMapRect(route.polyline.boundingMapRect,
                                   edgePadding: UIEdgeInsets(top: 28, left: 20, bottom: 28, right: 20),
                                   animated: false)
        } catch {
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (o.latitude + d.latitude) / 2,
                    longitude: (o.longitude + d.longitude) / 2),
                latitudinalMeters:  abs(o.latitude  - d.latitude)  * 111_000 * 1.4 + 10_000,
                longitudinalMeters: abs(o.longitude - d.longitude) * 111_000 * 1.4 + 10_000
            )
            map.setRegion(region, animated: false)
        }
    }

    private func geocode(_ name: String) async -> CLLocationCoordinate2D? {
        if #available(iOS 26.0, *) {
            guard let request = MKGeocodingRequest(addressString: name) else { return nil }
            return await withCheckedContinuation { continuation in
                request.getMapItems { items, _ in
                    guard let first = items?.first else {
                        continuation.resume(returning: nil)
                        return
                    }
                    if #available(iOS 26.0, *) {
                        continuation.resume(returning: first.location.coordinate)
                    } else {
                        continuation.resume(returning: first.placemark.coordinate)
                    }
                }
            }
        } else {
            let geocoder = CLGeocoder()
            let placemarks = try? await geocoder.geocodeAddressString(name)
            return placemarks?.first?.location?.coordinate
        }
    }

    private func mapItem(for coordinate: CLLocationCoordinate2D) -> MKMapItem {
        if #available(iOS 26.0, *) {
            return MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        } else {
            return MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
    }
}

// MARK: - Trip Detail Card
struct TripDetailCard: View {
    let trip: Trip
    let vehicle: Vehicle?
    let onStartInspection: () -> Void
    @State private var routeDash: CGFloat = 0

    private var formattedDate: String { trip.scheduledDate.formatted(.dateTime.day().month(.abbreviated).year()) }
    private var formattedTime: String { trip.scheduledDate.formatted(.dateTime.hour().minute()) }

    private var distanceDisplay: String {
        if let km = trip.distanceKm { return "\(Int(km))km" }
        if let oLat = trip.originLatitude, let oLng = trip.originLongitude,
           let dLat = trip.destinationLatitude, let dLng = trip.destinationLongitude {
            let km = CLLocation(latitude: oLat, longitude: oLng)
                .distance(from: CLLocation(latitude: dLat, longitude: dLng)) / 1000
            if km.isFinite, km > 0 { return "\(Int(km.rounded()))km" }
        }
        return "—"
    }

    // Whether pre-trip inspection is done (pre-trip only valid in Scheduled state)
    private var preInspectionDone: Bool { trip.preInspectionId != nil }
    private var withinStartWindow: Bool {
        trip.scheduledDate.timeIntervalSinceNow <= TripConstants.driverBlockWindowSeconds
            && trip.scheduledDate.timeIntervalSinceNow > -3600
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bus.fill").font(.system(size: 14, weight: .semibold)).foregroundColor(.appTextSecondary)
                Text(trip.taskId).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.appOrange)
                Spacer()
                if trip.isDriverWorkflowCompleted { CompletedBadge() }
                else { PriorityBadge(priority: trip.priority) }
            }

            RoutePreviewMap(
                originLat: trip.originLatitude, originLng: trip.originLongitude,
                destLat: trip.destinationLatitude, destLng: trip.destinationLongitude,
                originName: trip.origin, destName: trip.destination
            )
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar").font(.system(size: 15, weight: .semibold)).foregroundColor(.appOrange)
                    Text(formattedDate).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.appTextPrimary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill").font(.system(size: 15, weight: .semibold)).foregroundColor(.appOrange)
                    Text(formattedTime).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.appTextPrimary)
                }
            }

            HStack(spacing: 0) {
                Text(trip.origin.uppercased())
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.appTextPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                HStack(spacing: 0) {
                    DetailRouteLine(dashOffset: $routeDash).frame(width: 28, height: 2)
                    Text(distanceDisplay)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary).lineLimit(1).fixedSize()
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().stroke(Color.appOrange.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                    DetailRouteLine(dashOffset: $routeDash).frame(width: 28, height: 2)
                }
                Spacer(minLength: 8)
                Text(trip.destination.uppercased())
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.appTextPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }

            if let v = vehicle {
                HStack(spacing: 8) {
                    Text(v.licensePlate)
                        .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.appOrange)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.appOrange.opacity(0.08)))
                    Text("\(v.name) \(v.model)")
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.appTextSecondary)
                }
            }

            // Inspection / action area — respects state machine
            inspectionArea
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.appCardBg)
                .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { routeDash = -18 }
        }
    }

    @ViewBuilder
    private var inspectionArea: some View {
        if trip.isDriverWorkflowCompleted {
            if trip.postInspectionId != nil {
                CompletedInspectionButton()
            } else {
                SlideToStartInspectionButton(label: "Post-Trip Inspection", onComplete: onStartInspection)
            }
        } else if trip.status.normalized == .scheduled {
            if !preInspectionDone {
                // Pre-trip inspection needed
                SlideToStartInspectionButton(label: "Pre-Trip Inspection", onComplete: onStartInspection)
            } else if withinStartWindow {
                // Ready to start — green "Pre-Trip Done" state
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                    Text("Pre-Trip Done · Ready to Start")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12)))
                .overlay(Capsule().stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.35), lineWidth: 1.5))
            } else {
                // Pre-trip done but not yet within start window
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                    Text("Inspection Done · Starts at \(trip.scheduledDate.formatted(.dateTime.hour().minute()))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
                .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))
            }
        }
        // PendingAcceptance / Active: no action in this overlay — handled by list card buttons
    }
}

// MARK: - Slide To Start Inspection
struct SlideToStartInspectionButton: View {
    let label: String
    var controlHeight: CGFloat = 60
    let onComplete: () -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var isCompleted: Bool = false
    private let horizontalPadding: CGFloat = 4
    private var knobHeight: CGFloat { max(34, controlHeight - 8) }
    private var knobWidth: CGFloat { knobHeight + 10 }

    var body: some View {
        GeometryReader { geo in
            let maxOffset = max(0, geo.size.width - knobWidth - (horizontalPadding * 2))
            let progress = maxOffset == 0 ? 0 : dragOffset / maxOffset
            let fillWidth = dragOffset > 0 ? min(geo.size.width, dragOffset + knobWidth + horizontalPadding) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appSurface)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [Color.appAmber.opacity(0.32), Color.appOrange.opacity(0.38)],
                                                  startPoint: .leading, endPoint: .trailing))
                            .frame(width: fillWidth)
                            .opacity(fillWidth > 0 ? 1 : 0)
                    }
                    .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))

                Text(label)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 60).lineLimit(1).minimumScaleFactor(0.82)
                    .opacity(max(0, 1.0 - (progress * 1.35)))

                Capsule()
                    .fill(LinearGradient(colors: [Color.appAmber, Color.appOrange, Color.appDeepOrange],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: knobWidth, height: knobHeight)
                    .overlay(Image(systemName: "chevron.right.2").font(.system(size: 16, weight: .black)).foregroundColor(.white))
                    .shadow(color: Color.appOrange.opacity(0.35), radius: 10, x: 0, y: 4)
                    .offset(x: dragOffset + horizontalPadding)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !isCompleted else { return }
                                dragOffset = min(max(0, value.translation.width), maxOffset)
                            }
                            .onEnded { _ in
                                guard !isCompleted else { return }
                                if dragOffset > maxOffset * 0.82 {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                        dragOffset = maxOffset; isCompleted = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onComplete() }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { resetSlider(animated: false) }
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { dragOffset = 0 }
                                }
                            }
                    )
            }
        }
        .frame(height: controlHeight)
        .onAppear { resetSlider(animated: false) }
    }

    private func resetSlider(animated: Bool) {
        let updates = { dragOffset = 0; isCompleted = false }
        if animated { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { updates() } }
        else { updates() }
    }
}

struct CompletedInspectionButton: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 14, weight: .bold))
            Text("Post-Trip Inspection Completed").font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12)))
        .overlay(Capsule().stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.35), lineWidth: 1.5))
    }
}

struct DetailRouteLine: View {
    @Binding var dashOffset: CGFloat
    var body: some View {
        RouteLine()
            .stroke(Color.appOrange.opacity(0.45),
                    style: StrokeStyle(lineWidth: 2, dash: [5, 4], dashPhase: dashOffset))
    }
}

struct AcceptRequiredOverlay: View {
    let onAccept: () -> Void
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0
    @State private var iconPulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Color.appOrange.opacity(0.15)).frame(width: 90, height: 90)
                        .scaleEffect(iconPulse ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: iconPulse)
                    Circle().fill(Color.appOrange).frame(width: 64, height: 64)
                        .shadow(color: Color.appOrange.opacity(0.4), radius: 16)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                }
                .onAppear { iconPulse = true }

                Text("Action Required").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.appTextPrimary)
                Text("This trip requires your acceptance before you can proceed.")
                    .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 2)

                Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onAccept() }) {
                    Text("Accept Trip")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill(Color.appOrange))
                }
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onDismiss() }) {
                    Text("Dismiss")
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.appTextSecondary)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 18).frame(maxWidth: 330)
            .background(RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial).shadow(color: Color.black.opacity(0.10), radius: 20, x: 0, y: 8))
            .padding(.horizontal, 24)
            .scaleEffect(scale).opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { scale = 1.0; contentOpacity = 1.0 }
        }
    }
}

struct WaitingVehicleOverlay: View {
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0
    @State private var hourglassRotation: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Color.appOrange.opacity(0.15)).frame(width: 90, height: 90)
                    Circle().fill(Color.appOrange).frame(width: 64, height: 64).shadow(color: Color.appOrange.opacity(0.4), radius: 16)
                    Image(systemName: "hourglass.circle.fill").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                        .rotationEffect(.degrees(hourglassRotation))
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: hourglassRotation)
                }
                .onAppear { hourglassRotation = 180 }

                Text("Waiting for Vehicle").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.appTextPrimary)
                Text("A new vehicle is being assigned. You'll be notified once it's ready.")
                    .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 2)

                Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onDismiss() }) {
                    Text("OK")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill(Color.appOrange))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 18).frame(maxWidth: 330)
            .background(RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial).shadow(color: Color.black.opacity(0.10), radius: 20, x: 0, y: 8))
            .padding(.horizontal, 24)
            .scaleEffect(scale).opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { scale = 1.0; contentOpacity = 1.0 }
        }
    }
}
