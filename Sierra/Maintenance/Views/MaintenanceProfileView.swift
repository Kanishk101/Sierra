import SwiftUI
import LocalAuthentication

/// Maintenance profile sheet aligned with Sierra card-based design.
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
    private var assignedTasks: Int { myTasks.filter { $0.isEffectivelyAssigned }.count }

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
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    statsCard
                    contactCard
                    professionalCard
                    securityCard
                    actionsCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(Color.appSurface.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appOrange)
                }
            }
        }
        .onAppear { isBiometricEnabled = BiometricPreference.isEnabled }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [Color.appOrange, Color.appDeepOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 64, height: 64)
                .overlay(
                    Text(member?.initials ?? "M")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(member?.displayName ?? "Maintenance Personnel")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)
                Text(member?.email ?? AuthManager.shared.currentUser?.email ?? "")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle()
                        .fill((member?.availability == .available) ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    Text((member?.availability == .available) ? "Available" : "Unavailable")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle((member?.availability == .available) ? Color.green : Color.appTextSecondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(cardBackground)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Work Summary")
            HStack(spacing: 10) {
                metricPill(value: assignedTasks, label: "Assigned", tint: .blue)
                metricPill(value: inProgressTasks, label: "In Progress", tint: .purple)
                metricPill(value: completedTasks, label: "Completed", tint: .green)
            }
            if let profile {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appOrange)
                    Text("\(profile.yearsOfExperience) years of experience")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Contact")
            infoRow("Phone", value: member?.phone ?? "Not set", icon: "phone.fill")
            infoRow("Address", value: member?.address ?? "Not set", icon: "house.fill")
            infoRow("Emergency Contact", value: member?.emergencyContactName ?? "Not set", icon: "person.crop.circle.badge.exclamationmark")
            infoRow("Emergency Phone", value: member?.emergencyContactPhone ?? "Not set", icon: "phone.badge.waveform.fill")
        }
        .padding(16)
        .background(cardBackground)
    }

    private var professionalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Professional")
            if let profile {
                infoRow("Certification", value: profile.certificationType, icon: "checkmark.seal.fill")
                infoRow("Cert Number", value: profile.certificationNumber, icon: "number")
                infoRow("Authority", value: profile.issuingAuthority, icon: "building.columns.fill")
                infoRow("Expiry", value: profile.certificationExpiry, icon: "calendar.badge.clock")

                if !profile.specializations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Specializations")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                        specializationChips(profile.specializations)
                    }
                }
            } else {
                Text("Professional profile is not available yet.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Security")

            HStack {
                Label(biometricLabel, systemImage: biometricIcon)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Toggle("", isOn: $isBiometricEnabled)
                    .labelsHidden()
                    .tint(Color.appOrange)
                    .disabled(!biometric.canUseBiometrics())
                    .onChange(of: isBiometricEnabled) { _, enabled in
                        BiometricPreference.isEnabled = enabled
                    }
            }
            .padding(.vertical, 2)

            NavigationLink {
                ChangePasswordView()
            } label: {
                HStack {
                    Label("Change Password", systemImage: "lock.rotation")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {
            NavigationLink {
                MaintenanceProfileEditView()
                    .environment(store)
            } label: {
                HStack {
                    Label("Edit Profile", systemImage: "square.and.pencil")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appOrange)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color.appOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                AuthManager.shared.signOut()
                dismiss()
            } label: {
                HStack {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.appCardBg)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider.opacity(0.45), lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color.appTextPrimary)
    }

    private func infoRow(_ title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appOrange)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func metricPill(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.16), lineWidth: 1))
    }

    private func specializationChips(_ values: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appSurface, in: Capsule())
                        .overlay(Capsule().stroke(Color.appDivider.opacity(0.7), lineWidth: 1))
                }
            }
        }
    }
}

#Preview {
    MaintenanceProfileView()
        .environment(AppDataStore.shared)
}
