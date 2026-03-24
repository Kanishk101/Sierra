import SwiftUI
import LocalAuthentication

/// Driver profile sheet — accessible via header avatar in DriverHomeView.
struct DriverProfileSheet: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    // FIX: initialise from the canonical single source of truth.
    // Previously BiometricAuthManager.isEnabled routed through here fine,
    // but the onChange triggered a Face ID challenge just to SET the preference.
    // AdminProfileView documents this as a bug and avoids it — driver sheet
    // now uses the same correct pattern: write preference directly, no challenge.
    @State private var isBiometricEnabled = BiometricPreference.isEnabled
    private let biometric = BiometricManager.shared

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

    @State private var showChangePassword = false

    private var user: AuthUser? { AuthManager.shared.currentUser }

    private var driverMember: StaffMember? {
        guard let userId = user?.id else { return nil }
        return store.staff.first { $0.id == userId }
    }

    private var completedTrips: Int {
        guard let member = driverMember else { return 0 }
        return store.trips.filter { $0.driverId == member.id.uuidString && $0.status == .completed }.count
    }

    private var totalDistanceKm: Int {
        guard let member = driverMember else { return 0 }
        let myTrips = store.trips.filter { $0.driverId == member.id.uuidString && $0.status == .completed }
        let total = myTrips.reduce(0.0) { acc, trip in
            guard let s = trip.startMileage, let e = trip.endMileage else { return acc }
            return acc + (e - s)
        }
        return Int(total)
    }

    var body: some View {
        NavigationStack {
            List {
                // Profile Header
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
                                Text(driverMember?.initials ?? "D")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(driverMember?.displayName ?? user?.name ?? "Driver")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)

                            Text(user?.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let member = driverMember {
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

                // Stats
                Section("Trip Statistics") {
                    HStack {
                        Label("Completed Trips", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                        Spacer()
                        Text("\(completedTrips)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    HStack {
                        Label("Total Distance", systemImage: "road.lanes")
                            .font(.subheadline)
                        Spacer()
                        Text("\(totalDistanceKm) km")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }

                // Contact
                Section("Contact") {
                    if let phone = driverMember?.phone {
                        HStack {
                            Label("Phone", systemImage: "phone.fill")
                                .font(.subheadline)
                            Spacer()
                            Text(phone)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let email = user?.email {
                        HStack {
                            Label("Email", systemImage: "envelope.fill")
                                .font(.subheadline)
                            Spacer()
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // License + Documents Info
                if let profile = driverMember.flatMap({ store.driverProfile(for: $0.id) }) {
                    Section("License") {
                        HStack {
                            Label("License No.", systemImage: "doc.text.fill")
                                .font(.subheadline)
                            Spacer()
                            Text(profile.licenseNumber)
                                .font(.system(size: 13, design: .monospaced).weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        HStack {
                            Label("Class", systemImage: "creditcard.fill")
                                .font(.subheadline)
                            Spacer()
                            Text(profile.licenseClass)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Issuing State", systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                            Spacer()
                            Text(profile.licenseIssuingState)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Expiry", systemImage: "calendar.badge.clock")
                                .font(.subheadline)
                            Spacer()
                            Text(profile.licenseExpiry)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Documents") {
                        HStack {
                            Label("License Doc", systemImage: "doc.richtext.fill")
                                .font(.subheadline)
                            Spacer()
                            Text(profile.licenseDocumentUrl != nil ? "Uploaded ✓" : "Not uploaded")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(profile.licenseDocumentUrl != nil ? .green : .secondary)
                        }
                        HStack {
                            Label("Aadhaar Card", systemImage: "person.text.rectangle.fill")
                                .font(.subheadline)
                            Spacer()
                            Text(profile.aadhaarDocumentUrl != nil ? "Uploaded ✓" : "Not uploaded")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(profile.aadhaarDocumentUrl != nil ? .green : .secondary)
                        }
                    }
                }

                // Security
                Section("Security") {
                    Toggle(isOn: $isBiometricEnabled) {
                        Label(biometricLabel, systemImage: biometricIcon)
                            .font(.subheadline)
                    }
                    .tint(.orange)
                    .disabled(!biometric.canUseBiometrics())
                    // FIX: do NOT trigger a biometric challenge just to SET the preference.
                    // The challenge happens at sign-in time, not at settings-change time.
                    // Previously this called BiometricAuthManager.authenticate() which
                    // silently reverted the toggle to false on any Face ID failure —
                    // making it impossible to enable biometrics. Match AdminProfileView.
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

                // Sign Out
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
        // Sync toggle when sheet re-appears
        .onAppear { isBiometricEnabled = BiometricPreference.isEnabled }
    }
}

#Preview {
    DriverProfileSheet()
        .environment(AppDataStore.shared)
}
