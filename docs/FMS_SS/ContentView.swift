import SwiftUI

// MARK: - Home View
struct HomeView: View {
    @State private var isAvailable: Bool = true
    @State private var showStatusToast: Bool = false
    @StateObject private var viewModel = HomeViewModel()
    var onOpenTrips: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            Color.appSurface
                .ignoresSafeArea(edges: .top)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    HeaderSection(
                        isAvailable: $isAvailable,
                        showStatusToast: $showStatusToast
                    )

                    VStack(spacing: 16) {
                        if let fallback = viewModel.fallbackErrorMessage {
                            AppFallbackErrorBanner(
                                message: fallback,
                                onDismiss: { viewModel.clearFallbackError() }
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }

                        CurrentRouteBanner()
                            .padding(.top, -30)

                        UpcomingRidesCard(onOpenTrips: onOpenTrips)

                        // Section Title
                        HStack {
                            Text("Recent Trips")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.appTextPrimary)
                            Spacer()
                            Button(action: onOpenTrips) {
                                Text("View All")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.appOrange)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // Trip Cards
                        VStack(spacing: 12) {
                            if viewModel.loadState == .loading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                            } else if viewModel.recentTrips.isEmpty {
                                AppEmptyStateCard(
                                    title: "No Recent Trips",
                                    subtitle: "Recent completed or upcoming trips will appear here.",
                                    actionTitle: "Open Trips",
                                    action: onOpenTrips
                                )
                            } else {
                                ForEach(viewModel.recentTrips) { trip in
                                    AllTripCard(
                                        trip: trip,
                                        isJustAccepted: false,
                                        onAccept: onOpenTrips,
                                        onViewDetails: onOpenTrips,
                                        onPostTripInspection: onOpenTrips
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 20)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)

            // Availability Status Toast
            if showStatusToast {
                AvailabilityToast(isAvailable: isAvailable)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .zIndex(100)
            }
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            viewModel.load()
        }
    }
}

// MARK: - Availability Toast
struct AvailabilityToast: View {
    let isAvailable: Bool
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            // Animated pulsing dot
            ZStack {
                Circle()
                    .fill(isAvailable ? Color.green.opacity(0.25) : Color.red.opacity(0.25))
                    .frame(width: 28, height: 28)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(isAvailable ? Color.green : Color.red.opacity(0.8))
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isAvailable ? "You're Available" : "You're Offline")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(isAvailable ? "Ready to accept rides" : "You won't receive new rides")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer()

            Image(systemName: isAvailable ? "checkmark.circle.fill" : "moon.fill")
                .font(.system(size: 22))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(
                    isAvailable
                        ? Color.green.opacity(0.9)
                        : Color(red: 0.35, green: 0.35, blue: 0.40)
                )
                .shadow(
                    color: (isAvailable ? Color.green : Color.black).opacity(0.3),
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
                pulseScale = 1.5
            }
        }
    }
}

// MARK: - Header Section
struct HeaderSection: View {
    @Binding var isAvailable: Bool
    @Binding var showStatusToast: Bool

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.appAmber,
                    Color.appOrange,
                    Color.appDeepOrange.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Depth overlays
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
                // Availability toggle
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isAvailable ? Color.green : Color.gray)
                            .frame(width: 9, height: 9)
                            .shadow(
                                color: isAvailable ? Color.green.opacity(0.6) : Color.clear,
                                radius: 4
                            )
                            .animation(.easeInOut(duration: 0.3), value: isAvailable)

                        Toggle("", isOn: $isAvailable)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .labelsHidden()
                            .scaleEffect(0.85)
                            .onChange(of: isAvailable) { _ in
                                // Haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()

                                // Show toast
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                    showStatusToast = true
                                }

                                // Auto-dismiss
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    withAnimation(.easeOut(duration: 0.35)) {
                                        showStatusToast = false
                                    }
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                // Greeting
                Text(greetingText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(0.5)

                Text("SAUMYA SINGH")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.2)

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

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default:      return "Good Night"
        }
    }
}

// MARK: - Current Route Banner
struct CurrentRouteBanner: View {
    var body: some View {
        Button(action: {}) {
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
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}

// MARK: - Upcoming Rides Card
struct UpcomingRidesCard: View {
    var onOpenTrips: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("3 upcoming Rides")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)

                    Text("First Ride in 5 min")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
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

            Button(action: onOpenTrips) {
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
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview
#Preview {
    HomeView()
}
