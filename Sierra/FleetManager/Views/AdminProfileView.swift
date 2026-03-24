import SwiftUI
import LocalAuthentication

struct AdminProfileView: View {
    @Environment(\.dismiss) private var dismiss

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
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
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
                    }
                    HStack {
                        Label("Role", systemImage: "person.crop.rectangle")
                            .font(.subheadline)
                        Spacer()
                        Text("Fleet Manager")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }

                Section("Security") {
                    Toggle(isOn: $isBiometricEnabled) {
                        Label(biometricName, systemImage: biometricIcon)
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
}
