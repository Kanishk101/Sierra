import SwiftUI

struct TripOverviewView: View {
    let trip: Trip
    let onClose: () -> Void
    var onTripEnded: () -> Void = {}

    @StateObject private var viewModel = TripOverviewViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.appSurface.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        heroMapSection
                        routePlanCard
                        vehicleCard
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                if let fallback = viewModel.fallbackErrorMessage {
                    AppFallbackErrorBanner(message: fallback, onDismiss: { viewModel.clearError() })
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                }

                Button(action: { viewModel.openNavigation() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Navigate")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.90, green: 0.22, blue: 0.18))
                    )
                    .shadow(color: Color.red.opacity(0.22), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
                .buttonStyle(.plain)
            }
            .navigationTitle("Trip Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.appSurface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.appTextPrimary)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showActiveNavigation) {
            ActiveNavigationView(
                trip: trip,
                onEndTrip: {
                    viewModel.showActiveNavigation = false
                    onTripEnded()
                    onClose()
                }
            )
        }
        .onAppear {
            viewModel.load(trip: trip)
        }
    }

    private var heroMapSection: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.90, green: 0.95, blue: 0.92), Color(red: 0.92, green: 0.93, blue: 0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(mapGrid)
                .overlay(mapRoutePath)
                .frame(height: 320)

            VStack(spacing: 0) {
                HStack {
                    floatingChip(text: "Live Tracking", icon: "circle.fill", iconColor: .green)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                Spacer()

                floatingSummaryCard
                    .padding(12)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.appDivider.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
    }

    private var mapGrid: some View {
        ZStack {
            GeometryReader { geo in
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height
                    stride(from: 0.0, through: width, by: 44).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    stride(from: 0.0, through: height, by: 44).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }

    private var mapRoutePath: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: geo.size.width * 0.16, y: geo.size.height * 0.72))
                path.addCurve(
                    to: CGPoint(x: geo.size.width * 0.82, y: geo.size.height * 0.18),
                    control1: CGPoint(x: geo.size.width * 0.45, y: geo.size.height * 0.62),
                    control2: CGPoint(x: geo.size.width * 0.57, y: geo.size.height * 0.20)
                )
            }
            .stroke(Color.blue.opacity(0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 6]))
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }

    private var floatingSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Route")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                Spacer()
                Text("4 Stops")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.appOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.appOrange.opacity(0.12)))
            }

            HStack(spacing: 6) {
                Image(systemName: "number.square.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.appOrange)
                Text(trip.tripCode)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.appOrange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            HStack(spacing: 12) {
                topStat(icon: "arrow.up.right", label: "Distance", value: "\(trip.distanceKm) km", tint: .blue)
                topStat(icon: "clock", label: "ETA", value: "2h 30m", tint: .green)
                topStat(icon: "location.north.fill", label: "Route", value: "NH-48", tint: .appOrange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.97))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private var routePlanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Route Plan")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    Circle()
                        .fill(Color.green.opacity(0.14))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.green)
                        )

                    Rectangle()
                        .fill(
                            LinearGradient(colors: [.green, .appOrange], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 3, height: 52)

                    Circle()
                        .fill(Color.appOrange.opacity(0.14))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.appOrange)
                        )
                }

                VStack(alignment: .leading, spacing: 12) {
                    routeNode(
                        badge: "START",
                        badgeColor: .green,
                        city: trip.origin.uppercased(),
                        subtitle: "Fleet Depot - Bay 7",
                        meta: "10:00 AM"
                    )

                    routeNode(
                        badge: "DESTINATION",
                        badgeColor: .appOrange,
                        city: trip.destination.uppercased(),
                        subtitle: "Distribution Center - Zone A",
                        meta: "ETA 12:30 PM"
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.appDivider.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }

    private var vehicleCard: some View {
        HStack {
            Image(systemName: "bus.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appTextSecondary)

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
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.appDivider.opacity(0.8), lineWidth: 1)
        )
    }

    private func routeNode(
        badge: String,
        badgeColor: Color,
        city: String,
        subtitle: String,
        meta: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(badge)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(badgeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(badgeColor.opacity(0.10)))

            Text(city)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.appTextSecondary)
            Label(meta, systemImage: "clock")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.appTextSecondary)
        }
    }

    private func topStat(icon: String, label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle()
                    .fill(tint.opacity(0.13))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(tint)
                    )
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextSecondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func floatingChip(text: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(iconColor)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.96)))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    TripOverviewView(
        trip: Trip(
            id: "preview",
            tripCode: "TRP-20260315-102",
            origin: "Bengaluru",
            destination: "Hubli",
            fleetNumber: "FL-4096",
            vehicleType: "Sleeper Coach Volvo",
            dateTime: "15 Mar at 7:00 AM",
            distanceKm: 142
        ),
        onClose: {}
    )
}
