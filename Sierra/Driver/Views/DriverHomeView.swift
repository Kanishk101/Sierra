import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

/// Driver home screen embedded in the Home tab.
/// Shows greeting, availability toggle, and current assignment.
struct DriverHomeView: View {

    @Environment(AppDataStore.self) private var store

    private var user: AuthUser? { AuthManager.shared.currentUser }

    /// The StaffMember record for the current driver in AppDataStore.
    private var driverMember: StaffMember? {
        guard let userId = user?.id else { return nil }
        return store.staff.first { $0.id == userId }
            ?? store.staff.first { $0.role == .driver && $0.status == .active }
    }

    /// Active/scheduled trip for this driver.
    private var currentTrip: Trip? {
        guard let member = driverMember else { return nil }
        return store.activeTrip(forDriverId: member.id.uuidString)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Greeting card
                greetingCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Availability toggle
                availabilityCard
                    .padding(.horizontal, 16)

                // Current assignment
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
        .background(Color(hex: "F2F3F7").ignoresSafeArea())
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ─────────────────────────────────
    // MARK: - Greeting Card
    // ─────────────────────────────────

    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greetingText)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B3A6B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let firstName = driverMember?.name.split(separator: " ").first.map(String.init) ?? user?.name?.split(separator: " ").first.map(String.init) ?? "Driver"
        let timeOfDay: String
        if hour < 12 { timeOfDay = "morning" }
        else if hour < 17 { timeOfDay = "afternoon" }
        else { timeOfDay = "evening" }
        return "Good \(timeOfDay), \(firstName)"
    }

    // ─────────────────────────────────
    // MARK: - Availability Toggle Card
    // ─────────────────────────────────

    private var isAvailable: Bool {
        driverMember?.availability == .available
    }

    private var availabilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("My Availability")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(navyDark)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isAvailable ? "Available for Trips" : "Unavailable")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isAvailable ? .green : .secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isAvailable },
                    set: { newValue in
                        toggleAvailability(newValue)
                    }
                ))
                .labelsHidden()
                .tint(.green)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func toggleAvailability(_ available: Bool) {
        guard var member = driverMember else { return }
        member.availability = available ? .available : .unavailable
        store.updateStaff(member)
    }

    // ─────────────────────────────────
    // MARK: - Active Trip Card
    // ─────────────────────────────────

    private func activeTripCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("ACTIVE ASSIGNMENT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accentOrange)
                .kerning(1.2)

            // Task ID
            Text(trip.taskId)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.12), in: Capsule())

            // Route
            Text("\(trip.origin) → \(trip.destination)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(navyDark)

            // Vehicle info
            if let vId = trip.vehicleId,
               let vehicle = store.vehicle(forId: vId) {
                HStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(vehicle.licensePlate)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1), in: Capsule())
                    Text("\(vehicle.name) \(vehicle.model)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            // Scheduled time
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            // View Details button
            NavigationLink(value: trip.id) {
                Text("View Details")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentOrange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(accentOrange.opacity(0.5), lineWidth: 1.5)
                    )
            }
        }
        .padding(16)
        .background {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(accentOrange)
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
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.gray)

            Text("Your Fleet Manager hasn't assigned\na delivery task yet.")
                .font(.system(size: 14))
                .foregroundStyle(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            // Availability reminder
            if isAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                    Text("You're Available — waiting for assignment")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.green.opacity(0.08), in: Capsule())
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)
                        Text("Set yourself as Available to receive trips")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.08), in: Capsule())

                    Button {
                        toggleAvailability(true)
                    } label: {
                        Text("Set Available")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(accentOrange, in: Capsule())
                    }
                }
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
}

#Preview {
    NavigationStack {
        DriverHomeView()
            .environment(AppDataStore.shared)
    }
}
