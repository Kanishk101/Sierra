import SwiftUI


/// Driver home screen embedded in the Home tab.
/// Shows greeting, availability toggle, and current assignment.
struct DriverHomeView: View {

    @Environment(AppDataStore.self) private var store

    private var user: AuthUser? { AuthManager.shared.currentUser }

    /// The StaffMember record for the current driver in AppDataStore.
    /// Uses the authenticated user's UUID for exact match.
    private var driverMember: StaffMember? {
        guard let userId = user?.id else { return nil }
        return store.staff.first { $0.id == userId }
    }

    private var isAvailable: Bool {
        driverMember?.availability == .available
    }

    /// Active/scheduled trip for this driver.
    private var currentTrip: Trip? {
        guard let member = driverMember else { return nil }
        return store.activeTrip(forDriverId: member.id)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                greetingCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                availabilityCard
                    .padding(.horizontal, 16)

                if let trip = currentTrip {
                    activeTripCard(trip)
                        .padding(.horizontal, 16)
                } else {
                    noTripAssignedCard
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 20)
            }
        }
        .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ─────────────────────────────────
    // MARK: - Greeting Card
    // ─────────────────────────────────

    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greetingText)
                .font(SierraFont.title3)
                .foregroundStyle(.white)

            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(SierraFont.caption1)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let firstName: String =
            driverMember?.displayName.split(separator: " ").first.map(String.init)
            ?? user?.name?.split(separator: " ").first.map(String.init)
            ?? "Driver"
        let timeOfDay = hour < 12 ? "morning" : hour < 17 ? "afternoon" : "evening"
        return "Good \(timeOfDay), \(firstName)"
    }

    // ─────────────────────────────────
    // MARK: - Availability Toggle Card
    // ─────────────────────────────────

    private var availabilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("My Availability")
                .font(SierraFont.body(16, weight: .bold))
                .foregroundStyle(SierraTheme.Colors.primaryText)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isAvailable ? "Available for Trips" : "Unavailable")
                        .font(SierraFont.subheadline)
                        .foregroundStyle(isAvailable ? .green : .secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isAvailable },
                    set: { newValue in
                        guard let id = driverMember?.id else {
                            print("[DriverHomeView] toggleAvailability: driverMember is nil — store.staff.count=\(store.staff.count)")
                            return
                        }
                        Task {
                            do {
                                try await store.updateDriverAvailability(staffId: id, available: newValue)
                            } catch {
                                print("[DriverHomeView] availability update FAILED: \(error)")
                            }
                        }
                    }
                ))
                .labelsHidden()
                .tint(.green)
            }
        }
        .padding(16)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // ─────────────────────────────────
    // MARK: - Active Trip Card
    // ─────────────────────────────────

    private func activeTripCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVE ASSIGNMENT")
                .font(SierraFont.body(11, weight: .bold))
                .foregroundStyle(SierraTheme.Colors.ember)
                .kerning(1.2)

            Text(trip.taskId)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.12), in: Capsule())

            Text("\(trip.origin) \u{2192} \(trip.destination)")
                .font(SierraFont.body(16, weight: .bold))
                .foregroundStyle(SierraTheme.Colors.primaryText)

            if let vId = trip.vehicleId,
               let vUUID = UUID(uuidString: vId),
               let vehicle = store.vehicle(for: vUUID) {
                HStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(SierraFont.caption2)
                        .foregroundStyle(.secondary)
                    Text(vehicle.licensePlate)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1), in: Capsule())
                    Text("\(vehicle.name) \(vehicle.model)")
                        .font(SierraFont.caption1)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(SierraFont.caption2)
                    .foregroundStyle(.secondary)
                Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(SierraFont.caption1)
                    .foregroundStyle(.secondary)
            }

            NavigationLink(value: trip.id) {
                Text("View Details")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.ember)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(SierraTheme.Colors.ember.opacity(0.5), lineWidth: 1.5)
                    )
            }
        }
        .padding(16)
        .background {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(SierraTheme.Colors.ember)
                    .frame(width: 4)
                Color.white
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // ─────────────────────────────────
    // MARK: - No Trip Assigned Card
    // ─────────────────────────────────

    private var noTripAssignedCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 50))
                .foregroundStyle(.gray.opacity(0.5))
                .padding(.top, 20)

            Text("No Trip Assigned")
                .font(SierraFont.body(18, weight: .bold))
                .foregroundStyle(.gray)

            Text("Your Fleet Manager hasn\u{2019}t assigned\na delivery task yet.")
                .font(SierraFont.caption1)
                .foregroundStyle(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            if isAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(SierraFont.caption1)
                        .foregroundStyle(SierraTheme.Colors.alpineMint)
                    Text("You\u{2019}re Available \u{2014} waiting for assignment")
                        .font(SierraFont.caption1)
                        .foregroundStyle(SierraTheme.Colors.alpineMint)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.green.opacity(0.08), in: Capsule())
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(SierraFont.caption1)
                            .foregroundStyle(SierraTheme.Colors.warning)
                        Text("Set yourself as Available to receive trips")
                            .font(SierraFont.caption1)
                            .foregroundStyle(SierraTheme.Colors.warning)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(SierraTheme.Colors.warning.opacity(0.08), in: Capsule())

                    Button {
                        guard let id = driverMember?.id else { return }
                        Task {
                            do {
                                try await store.updateDriverAvailability(staffId: id, available: true)
                            } catch {
                                print("[DriverHomeView] Set Available FAILED: \(error)")
                            }
                        }
                    } label: {
                        Text("Set Available")
                            .font(SierraFont.caption1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(SierraTheme.Colors.ember, in: Capsule())
                    }
                }
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
}

#Preview {
    NavigationStack {
        DriverHomeView()
            .environment(AppDataStore.shared)
    }
}
