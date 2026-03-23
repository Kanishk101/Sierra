import SwiftUI

// MARK: - Trips View
struct TripsView: View {
    enum InspectionMode {
        case pre
        case post
    }

    @StateObject private var viewModel = TripsViewModel()
    @State private var hasAppeared: Bool = false
    @State private var acceptedTripID: String? = nil
    @State private var showAcceptConfetti: Bool = false
    @State private var selectedTrip: Trip? = nil
    @State private var showInspection: Bool = false
    @State private var inspectionTrip: Trip? = nil
    @State private var showAcceptWarning: Bool = false
    @State private var showWaitingVehicleOverlay: Bool = false
    @State private var overviewTrip: Trip? = nil
    @State private var inspectionMode: InspectionMode = .pre

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appSurface
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Stats Header
                        StatsBar(stats: viewModel.tripStats)
                            .padding(.horizontal, 20)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : -20)

                        if let fallback = viewModel.fallbackErrorMessage {
                            AppFallbackErrorBanner(
                                message: fallback,
                                onDismiss: { viewModel.clearFallbackError() }
                            )
                            .padding(.horizontal, 20)
                        }

                        // Active filter indicator
                        if viewModel.selectedPriority != nil {
                            ActiveFilterBanner(
                                filter: viewModel.selectedPriority!,
                                onClear: { clearFilter() }
                            )
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        } else if viewModel.showCompletedOnly {
                            CompletedFilterBanner(onClear: { clearFilter() })
                                .padding(.horizontal, 20)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Trip Cards
                        LazyVStack(spacing: 14) {
                            if viewModel.filteredTrips.isEmpty {
                                AppEmptyStateCard(
                                    title: "No Trips Found",
                                    subtitle: "Try clearing filters or refresh trips.",
                                    actionTitle: "Clear Filters",
                                    action: { clearFilter() }
                                )
                            } else {
                                ForEach(Array(viewModel.filteredTrips.enumerated()), id: \.element.id) { index, trip in
                                    AllTripCard(
                                        trip: trip,
                                        isJustAccepted: acceptedTripID == trip.id,
                                        onAccept: { acceptTrip(trip) },
                                        onViewDetails: { handlePrimaryAction(for: trip) },
                                        onPostTripInspection: { openPostTripInspection(for: trip) }
                                    )
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
                        }
                        .padding(.horizontal, 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.filterMode)

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 8)
                }

                // Accept success overlay
                if showAcceptConfetti {
                    AcceptSuccessOverlay()
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .zIndex(200)
                }

                if showAcceptWarning {
                    AcceptRequiredOverlay(onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showAcceptWarning = false
                        }
                    })
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(250)
                }

                if showWaitingVehicleOverlay {
                    WaitingVehicleOverlay(onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showWaitingVehicleOverlay = false
                        }
                    })
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(260)
                }
            }
            .navigationTitle("All Trips")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // Filter section
                        Section("Filter by Priority") {
                            Button(action: { applyFilter(nil) }) {
                                Label(
                                    "All Trips",
                                    systemImage: (viewModel.selectedPriority == nil && !viewModel.showCompletedOnly) ? "checkmark.circle.fill" : "square.grid.2x2"
                                )
                            }

                            ForEach(TripPriority.allCases, id: \.self) { priority in
                                Button(action: { applyFilter(priority) }) {
                                    Label(
                                        priority.rawValue,
                                        systemImage: viewModel.selectedPriority == priority ? "checkmark.circle.fill" : priority.icon
                                    )
                                }
                            }

                            Button(action: { applyCompletedFilter() }) {
                                Label(
                                    "Completed",
                                    systemImage: viewModel.showCompletedOnly ? "checkmark.circle.fill" : "checkmark.seal.fill"
                                )
                            }
                        }

                        Divider()

                        // Sort
                        Button(action: { sortByPriority() }) {
                            Label("Sort by Priority", systemImage: "arrow.up.arrow.down")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill((viewModel.selectedPriority != nil || viewModel.showCompletedOnly) ? Color.appOrange.opacity(0.12) : Color.clear)
                                .frame(width: 36, height: 36)

                            Image(systemName: (viewModel.selectedPriority != nil || viewModel.showCompletedOnly) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.appOrange)
                        }
                    }
                }
            }
            // Trip Detail Popup Overlay — inside NavigationStack
            .overlay {
                if let trip = selectedTrip {
                    TripDetailOverlay(
                        trip: trip,
                        onDismiss: { dismissDetail() },
                        onStartInspection: {
                            startInspection(for: trip)
                        }
                    )
                    .transition(.opacity)
                    .zIndex(300)
                }
            }
            .navigationDestination(isPresented: $showInspection) {
                PreTripInspectionView(
                    inspectionMode: inspectionMode == .pre ? .preTrip : .postTrip,
                    inspectionTitle: inspectionMode == .pre ? "Pre-Trip Inspection" : "Post-Trip Inspection",
                    onInspectionCompleted: {
                        markInspectionComplete()
                    },
                    onVehicleChangeRequested: {
                        markVehicleChangeRequested()
                    }
                )
            }
            .fullScreenCover(item: $overviewTrip) { trip in
                TripOverviewView(
                    trip: trip,
                    onClose: {
                        overviewTrip = nil
                    },
                    onTripEnded: {
                        markTripEnded(trip)
                    }
                )
            }
        }
        .onAppear {
            viewModel.loadIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Actions
    private func acceptTrip(_ trip: Trip) {
        // Haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Mark accepted
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            viewModel.acceptTrip(id: trip.id)
            acceptedTripID = trip.id
        }

        // Show confetti overlay
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showAcceptConfetti = true
        }

        // Auto dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showAcceptConfetti = false
                acceptedTripID = nil
            }
        }
    }

    private func sortByPriority() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.5)) {
            viewModel.sortByPriority()
        }
    }

    private func applyFilter(_ priority: TripPriority?) {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            viewModel.applyFilter(priority)
        }
    }

    private func applyCompletedFilter() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            viewModel.applyCompletedFilter()
        }
    }

    private func clearFilter() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.4)) {
            viewModel.clearFilter()
        }
    }

    private func showTripDetail(_ trip: Trip) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            selectedTrip = trip
        }
    }

    private func dismissDetail() {
        withAnimation(.easeOut(duration: 0.25)) {
            selectedTrip = nil
        }
    }

    private func handlePrimaryAction(for trip: Trip) {
        if trip.isTripEnded && !trip.isPostTripInspectionCompleted {
            showTripDetail(trip)
        } else if trip.isInspectionCompleted && trip.vehicleStatus != .waitingReallocation && !trip.isTripEnded {
            overviewTrip = trip
        } else {
            showTripDetail(trip)
        }
    }

    private func openPostTripInspection(for trip: Trip) {
        guard trip.isTripEnded else {
            showTripDetail(trip)
            return
        }
        inspectionMode = .post
        inspectionTrip = trip
        showInspection = true
    }

    private func startInspection(for trip: Trip) {
        guard let currentTrip = viewModel.trip(for: trip.id) else { return }

        if currentTrip.vehicleStatus == .waitingReallocation {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            dismissDetail()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showWaitingVehicleOverlay = true
            }
            return
        }

        if currentTrip.isAccepted {
            inspectionMode = currentTrip.isTripEnded ? .post : .pre
            inspectionTrip = currentTrip
            dismissDetail()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showInspection = true
            }
        } else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            dismissDetail()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showAcceptWarning = true
            }
        }
    }

    private func markInspectionComplete() {
        guard let inspectionTrip else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            viewModel.markInspectionComplete(id: inspectionTrip.id, mode: inspectionMode)
        }
        self.inspectionTrip = nil
    }

    private func markTripEnded(_ trip: Trip) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            viewModel.markTripEnded(id: trip.id)
        }
    }

    private func markVehicleChangeRequested() {
        guard let inspectionTrip else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            viewModel.markVehicleChangeRequested(id: inspectionTrip.id)
        }
        self.inspectionTrip = nil
    }
}

// MARK: - Stats Bar
struct StatsBar: View {
    let stats: (total: Int, urgent: Int, accepted: Int)

    var body: some View {
        HStack(spacing: 0) {
            StatItem(value: "\(stats.total)", label: "Total", icon: "list.bullet", color: .appOrange)
            Divider()
                .frame(height: 32)
                .padding(.horizontal, 4)
            StatItem(value: "\(stats.urgent)", label: "Urgent", icon: "flame.fill", color: Color(red: 0.85, green: 0.18, blue: 0.15))
            Divider()
                .frame(height: 32)
                .padding(.horizontal, 4)
            StatItem(value: "\(stats.accepted)", label: "Accepted", icon: "checkmark.seal.fill", color: Color(red: 0.20, green: 0.65, blue: 0.32))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appCardBg)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.appDivider.opacity(0.5), lineWidth: 1)
        )
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Active Filter Banner
struct ActiveFilterBanner: View {
    let filter: TripPriority
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: filter.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(filter.color)

            Text("Showing \(filter.rawValue) trips")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            Spacer()

            Button(action: onClear) {
                HStack(spacing: 4) {
                    Text("Clear")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                }
                .foregroundColor(.appOrange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(filter.bgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(filter.borderColor, lineWidth: 1)
        )
    }
}

struct CompletedFilterBanner: View {
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))

            Text("Showing Completed trips")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            Spacer()

            Button(action: onClear) {
                HStack(spacing: 4) {
                    Text("Clear")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                }
                .foregroundColor(.appOrange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - All Trip Card
struct AllTripCard: View {
    let trip: Trip
    let isJustAccepted: Bool
    let onAccept: () -> Void
    let onViewDetails: () -> Void
    let onPostTripInspection: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top row — trip code + priority badge
            HStack {
                // Bus icon
                Image(systemName: "bus.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextSecondary)

                Text(trip.tripCode)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.appOrange)

                Spacer()

                // Priority / completion badge
                if trip.isTripEnded {
                    CompletedBadge()
                } else {
                    PriorityBadge(priority: trip.priority)
                }
            }

            // Route
            HStack(spacing: 10) {
                Text(trip.origin.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)

                // Animated route line
                RouteArrow()

                Text(trip.destination.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
            }

            // Fleet info
            HStack(spacing: 8) {
                Text(trip.fleetNumber)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.appOrange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.appOrange.opacity(0.08))
                    )

                Text(trip.vehicleType)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }

            // Date & time
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 13))
                    .foregroundColor(.appTextSecondary)
                Text(trip.dateTime)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
            }

            // Divider
            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 1)
                .padding(.vertical, 2)

            // Action buttons
            let isWaitingVehicle = trip.vehicleStatus == .waitingReallocation
            let isNavigateReady = trip.isInspectionCompleted && !isWaitingVehicle && !trip.isTripEnded
            let needsPostTrip = trip.isTripEnded && !trip.isPostTripInspectionCompleted
            let postTripDone = trip.isTripEnded && trip.isPostTripInspectionCompleted

            if needsPostTrip {
                SlideToStartInspectionButton(
                    label: "Post-Trip Inspection",
                    controlHeight: 44,
                    onComplete: onPostTripInspection
                )
            } else if postTripDone {
                CompletedInspectionButton()
            } else {
                HStack(spacing: 12) {
                let primaryLabel = needsPostTrip ? "Post-Trip Inspection" : (isWaitingVehicle ? "Waiting for Vehicle" : (isNavigateReady ? "Navigate" : "View Details"))
                let primaryIcon = needsPostTrip ? "checklist" : (isWaitingVehicle ? "hourglass.circle.fill" : (isNavigateReady ? "location.fill" : "doc.text.magnifyingglass"))
                let primaryTextColor: Color = isNavigateReady ? .white : .appOrange
                let primaryBgColor: Color = isNavigateReady ? Color(red: 0.90, green: 0.22, blue: 0.18) : Color.appOrange.opacity(0.08)

                Button(action: onViewDetails) {
                    HStack(spacing: 6) {
                        Image(systemName: primaryIcon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(primaryLabel)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(primaryTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(primaryBgColor)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isNavigateReady
                                    ? Color.clear
                                    : Color.appOrange.opacity(0.25),
                                lineWidth: 1.5
                            )
                    )
                }

                // Accept Trip — filled
                Button(action: needsPostTrip ? onPostTripInspection : onAccept) {
                    HStack(spacing: 6) {
                        Image(systemName: needsPostTrip ? "checklist.checked" : (trip.isTripEnded ? "checkmark.circle.fill" : (trip.isAccepted ? "checkmark.circle.fill" : "hand.thumbsup.fill")))
                            .font(.system(size: 13, weight: .semibold))
                        Text(needsPostTrip ? "Post-Trip Inspection" : (trip.isTripEnded ? "Completed" : (trip.isAccepted ? "Accepted" : "Accept Trip")))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(needsPostTrip ? .white : ((trip.isAccepted || trip.isTripEnded) ? Color(red: 0.20, green: 0.65, blue: 0.32) : .white))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                needsPostTrip
                                    ? Color.appTextPrimary
                                    : ((trip.isAccepted || trip.isTripEnded)
                                    ? Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12)
                                    : Color.appTextPrimary)
                            )
                    )
                    .overlay(
                        (!needsPostTrip && (trip.isAccepted || trip.isTripEnded))
                            ? Capsule().stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.3), lineWidth: 1.5)
                            : nil
                    )
                }
                .disabled((trip.isAccepted || trip.isTripEnded) && !needsPostTrip)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(
                    color: trip.priority.color.opacity(0.10),
                    radius: 14,
                    x: 0, y: 6
                )
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
        .scaleEffect(isPressed ? 0.97 : (isJustAccepted ? 1.02 : 1.0))
        .animation(.spring(response: 0.3), value: isJustAccepted)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct CompletedBadge: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
            Text("Completed")
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.10))
        )
        .overlay(
            Capsule()
                .stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.35), lineWidth: 1.5)
        )
    }
}

struct AcceptRequiredOverlay: View {
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 0.55
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.appOrange)
                        .frame(width: 78, height: 78)
                        .shadow(color: Color.appOrange.opacity(0.35), radius: 16, x: 0, y: 8)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("Accept Trip First")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)

                    Text("Go and accept the trip before starting pre-trip inspection.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDismiss()
                }) {
                    Text("OK")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 56)
                        .padding(.vertical, 15)
                        .background(
                            Capsule()
                                .fill(Color.appOrange)
                        )
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.12), radius: 28)
            )
            .scaleEffect(scale)
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.74)) {
                scale = 1.0
                contentOpacity = 1.0
            }
        }
    }
}

struct WaitingVehicleOverlay: View {
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 0.92
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.appOrange)

                    Text("Waiting for New Vehicle")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }

                Text("Fleet manager is reallocating a vehicle for this trip.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 2)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDismiss()
                }) {
                    Text("OK")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.appOrange)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: 330)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.10), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, 24)
            .scaleEffect(scale)
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                scale = 1.0
                contentOpacity = 1.0
            }
        }
    }
}

// MARK: - Priority Badge
struct PriorityBadge: View {
    let priority: TripPriority
    @State private var isPulsing: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if priority == .urgent {
                Circle()
                    .fill(priority.color)
                    .frame(width: 7, height: 7)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0.5 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                    .onAppear { isPulsing = true }
            }

            Text(priority.rawValue)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(priority.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(priority.bgColor)
        )
        .overlay(
            Capsule()
                .stroke(priority.borderColor, lineWidth: 1.5)
        )
    }
}

// MARK: - Route Arrow (animated dashes)
struct RouteArrow: View {
    @State private var dashOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            // Animated dashed line
            Line()
                .stroke(
                    Color.appOrange.opacity(0.5),
                    style: StrokeStyle(lineWidth: 2, dash: [5, 4], dashPhase: dashOffset)
                )
                .frame(width: 30, height: 2)

            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 9))
                .foregroundColor(.appOrange)
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                dashOffset = -18
            }
        }
    }
}

// Simple line shape
struct Line: Shape {
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
        VStack(spacing: 16) {
            ZStack {
                // Outer pulse ring
                Circle()
                    .fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.15))
                    .frame(width: 110, height: 110)
                    .scaleEffect(scale > 0.8 ? 1.3 : 0.8)

                // Inner circle
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
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 30)
        )
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.25)) {
                checkOpacity = 1.0
            }
        }
    }
}

// MARK: - Trip Detail Overlay (Blur + Popup)
struct TripDetailOverlay: View {
    let trip: Trip
    let onDismiss: () -> Void
    let onStartInspection: () -> Void

    @State private var cardScale: CGFloat = 0.85
    @State private var cardOpacity: Double = 0

    var body: some View {
        ZStack {
            // Blurred background — tap to dismiss
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Detail card
            TripDetailCard(trip: trip, onStartInspection: onStartInspection)
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

// MARK: - Trip Detail Card
struct TripDetailCard: View {
    let trip: Trip
    let onStartInspection: () -> Void
    @State private var routeDash: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header — trip code + priority
            HStack {
                Image(systemName: "bus.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextSecondary)

                Text(trip.tripCode)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.appOrange)

                Spacer()

                if trip.isTripEnded {
                    CompletedBadge()
                } else {
                    PriorityBadge(priority: trip.priority)
                }
            }

            if trip.vehicleStatus == .waitingReallocation {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appOrange)

                    Text("Waiting for new vehicle to be assigned")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color.appOrange.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.appOrange.opacity(0.3), lineWidth: 1)
                )
            }

            // Map placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.94, green: 0.94, blue: 0.93),
                                Color(red: 0.90, green: 0.91, blue: 0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 150)

                VStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.appTextSecondary.opacity(0.35))
                    Text("Route Preview")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary.opacity(0.5))
                }
            }

            // Date & Time row
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appOrange)
                    Text(trip.scheduledDate)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appOrange)
                    Text(trip.scheduledTime)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }
            }

            // Route with distance
            HStack(spacing: 0) {
                Text(trip.origin.uppercased())
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                // Animated dashed route with distance pill
                HStack(spacing: 0) {
                    DetailRouteLine(dashOffset: $routeDash)
                        .frame(width: 28, height: 2)

                    // Distance pill
                    Text("\(trip.distanceKm)km")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .stroke(Color.appOrange.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        )

                    DetailRouteLine(dashOffset: $routeDash)
                        .frame(width: 28, height: 2)
                }

                Spacer(minLength: 8)

                Text(trip.destination.uppercased())
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            // Fleet info
            HStack(spacing: 8) {
                Text(trip.fleetNumber)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.appOrange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.appOrange.opacity(0.08))
                    )

                Text(trip.vehicleType)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextSecondary)
            }

            // Slide to start inspection (or completed state)
            if trip.isTripEnded && trip.isPostTripInspectionCompleted {
                CompletedInspectionButton()
            } else {
                SlideToStartInspectionButton(
                    label: trip.isTripEnded ? "Post-Trip Inspection" : "Pre-Trip Inspection",
                    onComplete: onStartInspection
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.appCardBg)
                .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
        )
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                routeDash = -18
            }
        }
    }
}

// MARK: - Slide To Start
struct SlideToStartInspectionButton: View {
    let label: String
    var controlHeight: CGFloat = 60
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isCompleted: Bool = false

    private let horizontalPadding: CGFloat = 4

    private var knobHeight: CGFloat {
        max(34, controlHeight - 8)
    }

    private var knobWidth: CGFloat {
        knobHeight + 10
    }

    var body: some View {
        GeometryReader { geo in
            let maxOffset = max(0, geo.size.width - knobWidth - (horizontalPadding * 2))
            let progress = maxOffset == 0 ? 0 : dragOffset / maxOffset
            let fillWidth = dragOffset > 0
                ? min(geo.size.width, dragOffset + knobWidth + horizontalPadding)
                : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appSurface)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAmber.opacity(0.32), Color.appOrange.opacity(0.38)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: fillWidth)
                            .opacity(fillWidth > 0 ? 1 : 0)
                    }
                    .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))

                Text(label)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 60)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .opacity(max(0, 1.0 - (progress * 1.35)))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.appAmber, Color.appOrange, Color.appDeepOrange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: knobWidth, height: knobHeight)
                    .overlay(
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                    )
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
                                        dragOffset = maxOffset
                                        isCompleted = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        onComplete()
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                        resetSlider(animated: false)
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: controlHeight)
        .onAppear {
            resetSlider(animated: false)
        }
    }

    private func resetSlider(animated: Bool) {
        let updates = {
            dragOffset = 0
            isCompleted = false
        }
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                updates()
            }
        } else {
            updates()
        }
    }
}

struct CompletedInspectionButton: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .bold))
            Text("Post-Trip Inspection Completed")
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.35), lineWidth: 1.5)
        )
    }
}

// MARK: - Detail Route Line
struct DetailRouteLine: View {
    @Binding var dashOffset: CGFloat

    var body: some View {
        Line()
            .stroke(
                Color.appOrange.opacity(0.45),
                style: StrokeStyle(lineWidth: 2, dash: [5, 4], dashPhase: dashOffset)
            )
    }
}

// MARK: - Preview
#Preview {
    TripsView()
}
