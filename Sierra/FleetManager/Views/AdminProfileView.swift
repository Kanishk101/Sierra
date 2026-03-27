import SwiftUI
import LocalAuthentication

struct AdminProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccessibilitySettings.self) private var accessibilitySettings

    private var authManager = AuthManager.shared
    private let biometric = BiometricManager.shared
    @State private var isBiometricEnabled: Bool = BiometricPreference.isEnabled

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text(initials)
                                    .font(SierraFont.title2)
                                    .foregroundStyle(.white)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.name ?? "Fleet Manager")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)

                            Text(authManager.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }

                Section("Account") {
                    if let email = authManager.currentUser?.email {
                        HStack {
                            Label("Email", systemImage: "envelope.fill")
                                .font(.subheadline)
                            Spacer()
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    HStack {
                        Label("Role", systemImage: "person.crop.rectangle")
                            .font(.subheadline)
                        Spacer()
                        Text("Fleet Manager")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appOrange)
                    }
                    .accessibilityElement(children: .combine)
                }

                Section("Security") {
                    Toggle(isOn: $isBiometricEnabled) {
                        Label(biometricName, systemImage: biometricIcon)
                            .font(.subheadline)
                    }
                    .tint(Color.appOrange)
                    .disabled(!biometric.canUseBiometrics())
                    .onChange(of: isBiometricEnabled) { _, enabled in
                        BiometricPreference.isEnabled = enabled
                    }
                    .accessibilityLabel("\(biometricName) login")
                    .accessibilityHint("Enables biometric authentication for sign in")

                    NavigationLink {
                        ChangePasswordView()
                    } label: {
                        Label("Change Password", systemImage: "lock.rotation")
                            .font(.subheadline)
                    }
                    .accessibilityLabel("Change password")
                }

                Section("Accessibility") {
                    Toggle(isOn: Binding(
                        get: { accessibilitySettings.isColorBlindModeEnabled },
                        set: { accessibilitySettings.isColorBlindModeEnabled = $0 }
                    )) {
                        Label("Color Blind Mode", systemImage: "eyedropper.halffull")
                            .font(.subheadline)
                    }
                    .tint(Color.appOrange)
                    .accessibilityLabel("Color blind mode")
                    .accessibilityHint("Switches to a high-contrast color palette")

                    Text("Uses a high-contrast palette and non-color cues to improve readability.")
                        .font(SierraFont.caption1)
                        .foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
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
                    .accessibilityLabel("Sign out")
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close profile")
                }
            }
        }
        .onAppear {
            isBiometricEnabled = BiometricPreference.isEnabled
        }
    }

    // MARK: - Helpers

    private var initials: String {
        let name = authManager.currentUser?.name ?? "FM"
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.dropFirst().first?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }

    private var biometricIcon: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "lock.fill"
        }
        return context.biometryType == .faceID ? "faceid" : "touchid"
    }

    private var biometricName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Biometric Login"
        }
        return context.biometryType == .faceID ? "Face ID" : "Touch ID"
    }
}

#Preview {
    AdminProfileView()
        .environment(AccessibilitySettings.shared)
}
