import SwiftUI
import LocalAuthentication

/// Maintenance profile sheet — mirrors DriverProfileSheet structure
/// with maintenance-specific fields from onboarding/profile.
struct MaintenanceProfileView: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isBiometricEnabled = BiometricPreference.isEnabled

    private let biometric = BiometricManager.shared

    private var currentUserId: UUID? { AuthManager.shared.currentUser?.id }

    private var member: StaffMember? {
        guard let id = currentUserId else { return nil }
        return store.staff.first { $0.id == id }
    }

    private var profile: MaintenanceProfile? {
        guard let id = currentUserId else { return nil }
        return store.maintenanceProfile(for: id)
    }

    private var myTasks: [MaintenanceTask] {
        guard let id = currentUserId else { return [] }
        return store.maintenanceTasks.filter { $0.assignedToId == id }
    }

    private var completedTasks: Int { myTasks.filter { $0.status == .completed }.count }
    private var inProgressTasks: Int { myTasks.filter { $0.status == .inProgress }.count }
    private var assignedTasks: Int { myTasks.filter { $0.status == .assigned }.count }

    private var biometricLabel: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Biometric Login"
        }
        return context.biometryType == .faceID ? "Face ID" : "Touch ID"
    }

    private var biometricIcon: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "lock.fill"
        }
        return context.biometryType == .faceID ? "faceid" : "touchid"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .orange.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text(member?.initials ?? "M")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(member?.displayName ?? "Maintenance Personnel")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)

                            Text(member?.email ?? AuthManager.shared.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let member {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(member.availability == .available ? .green : .gray)
                                        .frame(width: 8, height: 8)
                                    Text(member.availability.rawValue.capitalized)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(member.availability == .available ? .green : .secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Work Statistics") {
                    statRow("Assigned Tasks", value: "\(assignedTasks)", icon: "tray.full.fill")
                    statRow("In Progress", value: "\(inProgressTasks)", icon: "wrench.and.screwdriver.fill")
                    statRow("Completed Tasks", value: "\(completedTasks)", icon: "checkmark.seal.fill")
                    if let profile {
                        statRow("Years of Experience", value: "\(profile.yearsOfExperience)", icon: "clock.arrow.circlepath")
                    }
                }

                Section("Contact") {
                    infoRow("Phone", value: member?.phone ?? "Not set", icon: "phone.fill")
                    infoRow("Email", value: member?.email ?? "Not set", icon: "envelope.fill")
                    infoRow("Address", value: member?.address ?? "Not set", icon: "house.fill")
                    infoRow("Emergency Contact", value: member?.emergencyContactName ?? "Not set", icon: "person.crop.circle.badge.exclamationmark")
                    infoRow("Emergency Phone", value: member?.emergencyContactPhone ?? "Not set", icon: "phone.badge.waveform.fill")
                }

                if let profile {
                    Section("Certification") {
                        infoRow("Type", value: profile.certificationType, icon: "checkmark.seal.fill")
                        infoRow("Number", value: profile.certificationNumber, icon: "number")
                        infoRow("Authority", value: profile.issuingAuthority, icon: "building.columns.fill")
                        infoRow("Expiry", value: profile.certificationExpiry, icon: "calendar.badge.clock")
                    }

                    Section("Specializations") {
                        if profile.specializations.isEmpty {
                            Text("No specializations added")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(profile.specializations, id: \.self) { spec in
                                Label(spec, systemImage: "wrench.adjustable.fill")
                                    .font(.subheadline)
                            }
                        }
                    }

                    Section("Documents") {
                        infoRow("Certification Doc", value: profile.certificationDocumentUrl != nil ? "Uploaded ✓" : "Not uploaded", icon: "doc.richtext.fill", valueTint: profile.certificationDocumentUrl != nil ? .green : .secondary)
                        infoRow("Aadhaar Doc", value: profile.aadhaarDocumentUrl != nil ? "Uploaded ✓" : "Not uploaded", icon: "person.text.rectangle.fill", valueTint: profile.aadhaarDocumentUrl != nil ? .green : .secondary)
                    }
                }

                Section("Security") {
                    Toggle(isOn: $isBiometricEnabled) {
                        Label(biometricLabel, systemImage: biometricIcon)
                            .font(.subheadline)
                    }
                    .tint(.orange)
                    .disabled(!biometric.canUseBiometrics())
                    .onChange(of: isBiometricEnabled) { _, enabled in
                        BiometricPreference.isEnabled = enabled
                    }

                    NavigationLink {
                        ChangePasswordView()
                    } label: {
                        Label("Change Password", systemImage: "lock.rotation")
                            .font(.subheadline)
                    }
                }

                Section("Profile") {
                    NavigationLink {
                        MaintenanceProfileEditView()
                            .environment(store)
                    } label: {
                        Label("Edit Profile", systemImage: "square.and.pencil")
                            .font(.subheadline)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        AuthManager.shared.signOut()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { isBiometricEnabled = BiometricPreference.isEnabled }
    }

    private func statRow(_ title: String, value: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
        }
    }

    private func infoRow(_ title: String, value: String, icon: String, valueTint: Color = .secondary) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(valueTint)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    MaintenanceProfileView()
        .environment(AppDataStore.shared)
}
