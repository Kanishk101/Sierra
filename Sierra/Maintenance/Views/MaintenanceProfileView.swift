import SwiftUI
import LocalAuthentication

/// Maintenance profile sheet aligned with Sierra card-based design.
struct MaintenanceProfileView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(AccessibilitySettings.self) private var accessibilitySettings
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
                    accessibilityCard
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
                        .accessibilityLabel("Close profile")
                }
            }
        }
        .onAppear {
            isBiometricEnabled = BiometricPreference.isEnabled
            if let currentUserId {
                Task { await store.loadMaintenanceData(staffId: currentUserId) }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [Color.appOrange, Color.appDeepOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 64, height: 64)
                .overlay(
                    Text(member?.initials ?? "M")
                        .font(SierraFont.title2)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(member?.displayName ?? "Maintenance Personnel")
                    .font(SierraFont.title3)
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)
                Text(member?.email ?? AuthManager.shared.currentUser?.email ?? "")
                    .font(SierraFont.caption1)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle()
                        .fill((member?.availability == .available) ? Color.statusActive : Color.gray)
                        .frame(width: 7, height: 7)
                    Text((member?.availability == .available) ? "Available" : "Unavailable")
                        .font(SierraFont.caption2.weight(.bold))
                        .foregroundStyle((member?.availability == .available) ? Color.statusActive : Color.appTextSecondary)
                }
                .accessibilityLabel("Availability \((member?.availability == .available) ? "Available" : "Unavailable")")
            }
            Spacer()
        }
        .padding(16)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Work Summary")
            HStack(spacing: 10) {
                metricPill(value: assignedTasks, label: "Assigned", symbol: "tray.full.fill", tint: Color.appOrange)
                metricPill(value: inProgressTasks, label: "In Progress", symbol: "wrench.and.screwdriver.fill", tint: SierraTheme.Colors.info)
                metricPill(value: completedTasks, label: "Completed", symbol: "checkmark.seal.fill", tint: SierraTheme.Colors.success)
            }
            if let profile {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(SierraFont.caption1.weight(.semibold))
                        .foregroundStyle(Color.appOrange)
                    Text("\(profile.yearsOfExperience) years of experience")
                        .font(SierraFont.footnote.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
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
        .accessibilityElement(children: .contain)
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
                            .font(SierraFont.caption1.weight(.bold))
                            .foregroundStyle(Color.appTextSecondary)
                        specializationChips(profile.specializations)
                    }
                }
            } else {
                Text("Professional profile is not available yet.")
                    .font(SierraFont.body(14, weight: .medium))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding(16)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Security")

            HStack {
                Label(biometricLabel, systemImage: biometricIcon)
                    .font(SierraFont.body(14, weight: .semibold))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Toggle("", isOn: $isBiometricEnabled)
                    .labelsHidden()
                    .tint(Color.appOrange)
                    .disabled(!biometric.canUseBiometrics())
                    .onChange(of: isBiometricEnabled) { _, enabled in
                        BiometricPreference.isEnabled = enabled
                    }
                    .accessibilityLabel("\(biometricLabel) login")
                    .accessibilityHint("Enables biometric authentication for sign in")
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)

            NavigationLink {
                ChangePasswordView()
            } label: {
                HStack {
                    Label("Change Password", systemImage: "lock.rotation")
                        .font(SierraFont.body(14, weight: .semibold))
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(SierraFont.caption2.weight(.bold))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change password")
        }
        .padding(16)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
    }

    private var accessibilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Accessibility")

            HStack {
                Label("Color Blind Mode", systemImage: "eyedropper.halffull")
                    .font(SierraFont.body(14, weight: .semibold))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { accessibilitySettings.isColorBlindModeEnabled },
                    set: { accessibilitySettings.isColorBlindModeEnabled = $0 }
                ))
                .labelsHidden()
                .tint(Color.appOrange)
                .accessibilityLabel("Color blind mode")
                .accessibilityHint("Switches to a high-contrast color palette")
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)

            Text("High-contrast colors and clearer visual cues improve readability.")
                .font(SierraFont.caption1)
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(16)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {
            NavigationLink {
                MaintenanceProfileEditView()
                    .environment(store)
            } label: {
                HStack {
                    Label("Edit Profile", systemImage: "square.and.pencil")
                        .font(SierraFont.body(15, weight: .bold))
                        .foregroundStyle(Color.appOrange)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color.appOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit profile")

            Button(role: .destructive) {
                AuthManager.shared.signOut()
                dismiss()
            } label: {
                HStack {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(SierraFont.body(15, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel("Sign out")
        }
        .padding(16)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.appCardBg)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider.opacity(0.45), lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(SierraFont.body(14, weight: .bold))
            .foregroundStyle(Color.appTextPrimary)
    }

    private func infoRow(_ title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(SierraFont.caption1.weight(.semibold))
                .foregroundStyle(Color.appOrange)
                .frame(width: 18)
            Text(title)
                .font(SierraFont.footnote)
                .foregroundStyle(Color.appTextSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(SierraFont.footnote.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func metricPill(value: Int, label: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(SierraFont.caption2.weight(.semibold))
                .foregroundStyle(tint)
            Text("\(value)")
                .font(SierraFont.title3.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(SierraFont.caption2)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.16), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func specializationChips(_ values: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(SierraFont.caption2)
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
        .environment(AccessibilitySettings.shared)
}
