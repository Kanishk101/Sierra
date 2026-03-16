import SwiftUI


/// Driver home screen embedded in the Home tab.
/// Shows greeting, availability toggle, and current assignment.
struct DriverHomeView: View {

    @Environment(AppDataStore.self) private var store

    @State private var showProfile = false
    @State private var showToast = false
    @State private var toastMessage: String?

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
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Home")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button(action: { toggleAvailability(true) }) {
                        Label("Available", systemImage: isAvailable ? "checkmark" : "")
                    }
                    Button(action: { toggleAvailability(false) }) {
                        Label("Unavailable", systemImage: !isAvailable ? "checkmark" : "")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isAvailable ? Color(.systemGreen) : Color(.systemOrange))
                            .frame(width: 8, height: 8)
                        Text(isAvailable ? "Available" : "Unavailable")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .foregroundStyle(isAvailable ? Color(.systemGreen) : Color(.systemOrange))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: Capsule())
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showProfile = true } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Profile")
            }
        }
        .overlay(alignment: .top) {
            if showToast, let msg = toastMessage {
                HStack(spacing: 12) {
                    Image(systemName: isAvailable ? "checkmark.circle.fill" : "moon.fill")
                        .foregroundStyle(isAvailable ? Color(.systemGreen) : Color(.systemOrange))
                        .font(.title3)
                    Text(msg)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Capsule().fill(.regularMaterial).shadow(color: .black.opacity(0.1), radius: 10, y: 4))
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
                .zIndex(1)
            }
        }
        .sheet(isPresented: $showProfile) {
            AdminProfileView()
        }
    }

    // MARK: - Greeting Card

    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greetingText)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
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

    // MARK: - Active Trip Card

    private func activeTripCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVE ASSIGNMENT")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(.systemOrange))
                .kerning(1.2)

            Text(trip.taskId)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.12), in: Capsule())

            Text("\(trip.origin) \u{2192} \(trip.destination)")
                .font(.headline).foregroundStyle(.primary)

            if let vId = trip.vehicleId,
               let vUUID = UUID(uuidString: vId),
               let vehicle = store.vehicle(for: vUUID) {
                HStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(vehicle.licensePlate)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1), in: Capsule())
                    Text("\(vehicle.name) \(vehicle.model)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            NavigationLink(value: trip.id) {
                Text("View Details")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(.systemOrange))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(.systemOrange).opacity(0.5), lineWidth: 1.5))
            }
        }
        .padding(16)
        .background {
            HStack(spacing: 0) {
                Rectangle().fill(Color(.systemOrange)).frame(width: 4)
                Color(.systemBackground)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - No Trip Assigned Card

    private var noTripAssignedCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 50))
                .foregroundStyle(.gray.opacity(0.5))
                .padding(.top, 20)

            Text("No Trip Assigned")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Your Fleet Manager hasn\u{2019}t assigned\na delivery task yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            if isAvailable {
                Text("You\u{2019}re waiting for assignment")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(.systemGreen))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.systemGreen).opacity(0.1), in: Capsule())
            } else {
                VStack(spacing: 10) {
                    Text("Set yourself as Available to receive trips")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(.systemOrange))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemOrange).opacity(0.1), in: Capsule())

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
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(.orange, in: Capsule())
                    }
                }
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Availability Toggle

    private func toggleAvailability(_ available: Bool) {
        guard driverMember?.availability != .busy else { return }
        guard let id = driverMember?.id else {
            print("[DriverHomeView] toggleAvailability: driverMember is nil — store.staff.count=\(store.staff.count)")
            return
        }
        Task {
            do {
                try await store.updateDriverAvailability(staffId: id, available: available)
                toastMessage = available ? "You\u{2019}re now Available" : "You\u{2019}re now Unavailable"
                withAnimation(.spring(duration: 0.3)) { showToast = true }
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.spring(duration: 0.3)) { showToast = false }
            } catch {
                print("[DriverHomeView] availability update FAILED: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        DriverHomeView()
            .environment(AppDataStore.shared)
    }
}
