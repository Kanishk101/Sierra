import SwiftUI

// MARK: - Staff Detail Sheet

struct StaffDetailSheet: View {
    let member: StaffMember
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var assignedVehicle: Vehicle? {
        store.vehicles.first { $0.assignedDriverId == member.id.uuidString }
    }

    private var activeTrip: Trip? {
        guard member.role == .driver else { return nil }
        return store.activeTrip(forDriverId: member.id)
    }

    private var tripCount: Int {
        store.trips(forDriver: member.id).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    heroSection

                    statusRow
                        .padding(.horizontal, 20)

                    if let vehicle = assignedVehicle {
                        infoCard(title: "Assigned Vehicle", icon: "car.fill", color: .blue) {
                            labeledRow("Name", vehicle.name)
                            labeledRow("Plate", vehicle.licensePlate)
                            labeledRow("Model", vehicle.model)
                            labeledRow("Status", vehicle.status.rawValue)
                        }
                        .padding(.horizontal, 20)
                    } else if member.role == .driver {
                        infoCard(title: "Assigned Vehicle", icon: "car.fill", color: .secondary) {
                            Text("No vehicle assigned")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }

                    if let trip = activeTrip {
                        infoCard(title: "Current Trip", icon: "arrow.triangle.swap", color: .green) {
                            labeledRow("Route", "\(trip.origin) \u{2192} \(trip.destination)")
                            labeledRow("Status", trip.status.rawValue)
                            labeledRow("Task ID", trip.taskId)
                        }
                        .padding(.horizontal, 20)
                    }

                    infoCard(title: "Contact", icon: "person.crop.circle", color: .orange) {
                        labeledRow("Email", member.email)
                        if let phone = member.phone { labeledRow("Phone", phone) }
                        if let emergency = member.emergencyContactName {
                            labeledRow("Emergency Contact", emergency)
                        }
                        if let emergencyPhone = member.emergencyContactPhone {
                            labeledRow("Emergency Phone", emergencyPhone)
                        }
                    }
                    .padding(.horizontal, 20)

                    if member.isProfileComplete {
                        infoCard(title: "Profile", icon: "doc.text", color: .green) {
                            if let dob = member.dateOfBirth { labeledRow("Date of Birth", dob) }
                            if let gender = member.gender { labeledRow("Gender", gender) }
                            if let address = member.address { labeledRow("Address", address) }
                            if let aadhaar = member.aadhaarNumber { labeledRow("Aadhaar", aadhaar) }
                        }
                        .padding(.horizontal, 20)
                    }

                    infoCard(title: "Activity", icon: "chart.bar.fill", color: Color(.systemOrange)) {
                        labeledRow("Total Trips", "\(tripCount)")
                        labeledRow("Profile", member.isProfileComplete ? "Complete" : "Incomplete")
                        if let joined = member.joinedDate {
                            labeledRow("Joined", joined.formatted(.dateTime.day().month(.abbreviated).year()))
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 32)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(member.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(member.initials)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                )
            Text(member.displayName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            Text(member.displayRole)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 12) {
            miniStatusCard("Availability", member.availability.rawValue, availabilityColor(member.availability))
            miniStatusCard("Approved", member.isApproved ? "Yes" : "No",
                           member.isApproved ? .green : .red)
            miniStatusCard("Profile", member.isProfileComplete ? "Complete" : "Incomplete",
                           member.isProfileComplete ? .green : .orange)
        }
    }

    private func miniStatusCard(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Info Card

    private func infoCard<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    // MARK: - Color helpers

    private func availabilityColor(_ a: StaffAvailability) -> Color {
        switch a {
        case .available:   return .green
        case .unavailable: return .red
        case .busy:        return .orange
        }
    }
}
