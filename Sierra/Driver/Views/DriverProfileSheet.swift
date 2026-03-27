import SwiftUI
import LocalAuthentication
import CoreLocation

/// Driver profile sheet — accessible via header avatar in DriverHomeView.
struct DriverProfileSheet: View {

    @Environment(AppDataStore.self) private var store
    @Environment(AccessibilitySettings.self) private var accessibilitySettings
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
    @State private var showEditProfile = false
    @State private var isSavingProfile = false
    @State private var saveErrorMessage: String?

    @State private var editName = ""
    @State private var editPhone = ""
    @State private var editAddress = ""
    @State private var editEmergencyName = ""
    @State private var editEmergencyPhone = ""
    @State private var editLicenseNumber = ""
    @State private var editLicenseClass = ""
    @State private var editLicenseState = ""
    @State private var editLicenseExpiry = ""

    private var profileValidationErrors: [String] {
        var errors: [String] = []

        let name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.count < 2 {
            errors.append("Name must be at least 2 characters.")
        }

        if !editPhone.isEmpty && editPhone.count != 10 {
            errors.append("Mobile number must be exactly 10 digits.")
        }

        let emergencyName = editEmergencyName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !emergencyName.isEmpty && editEmergencyPhone.count != 10 {
            errors.append("Emergency contact number must be 10 digits.")
        }
        if emergencyName.isEmpty && !editEmergencyPhone.isEmpty {
            errors.append("Enter emergency contact name.")
        }

        let licenseNumber = editLicenseNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let licenseRegex = #"^[A-Z0-9-]{8,20}$"#
        if licenseNumber.isEmpty || licenseNumber.range(of: licenseRegex, options: .regularExpression) == nil {
            errors.append("License number must be 8-20 characters (A-Z, 0-9, -).")
        }

        let licenseClass = editLicenseClass.trimmingCharacters(in: .whitespacesAndNewlines)
        let licenseClassRegex = #"^[A-Z0-9-]{2,10}$"#
        if licenseClass.isEmpty || licenseClass.range(of: licenseClassRegex, options: .regularExpression) == nil {
            errors.append("License class must be 2-10 characters (A-Z, 0-9, -).")
        }

        let state = editLicenseState.trimmingCharacters(in: .whitespacesAndNewlines)
        if state.isEmpty {
            errors.append("Issuing state is required.")
        }

        let expiry = editLicenseExpiry.trimmingCharacters(in: .whitespacesAndNewlines)
        if !Self.isValidDateYYYYMMDD(expiry) {
            errors.append("Expiry must be in YYYY-MM-DD format.")
        } else if !Self.isFutureOrTodayDateYYYYMMDD(expiry) {
            errors.append("License expiry cannot be in the past.")
        }

        return errors
    }

    private var canSaveProfile: Bool {
        !isSavingProfile && profileValidationErrors.isEmpty
    }

    private var user: AuthUser? { AuthManager.shared.currentUser }

    private var driverMember: StaffMember? {
        guard let userId = user?.id else { return nil }
        return store.staff.first { $0.id == userId }
    }

    private var completedDriverTrips: [Trip] {
        guard let member = driverMember else { return [] }
        return store.trips(forDriver: member.id)
            .filter { $0.effectiveStatusForDriver == .completed }
    }

    private var completedTrips: Int {
        completedDriverTrips.count
    }

    private var totalDistanceKm: Int {
        let total = completedDriverTrips.reduce(0.0) { partial, trip in
            partial + estimatedTripDistanceKm(for: trip)
        }
        return Int(total.rounded())
    }

    private func estimatedTripDistanceKm(for trip: Trip) -> Double {
        let anchors = routeAnchors(for: trip)
        if anchors.count >= 2 {
            let metres = zip(anchors, anchors.dropFirst()).reduce(0.0) { partial, pair in
                let a = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                let b = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
                return partial + a.distance(from: b)
            }
            if metres > 0 { return metres / 1000.0 }
        }

        // Fallback when route coordinates are unavailable.
        if let km = trip.distanceKm, km > 0 { return km }
        return 0
    }

    private func routeAnchors(for trip: Trip) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        if let lat = trip.originLatitude, let lng = trip.originLongitude {
            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        if let stops = trip.routeStops, !stops.isEmpty {
            for stop in stops.sorted(by: { $0.order < $1.order }) {
                points.append(CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude))
            }
        }
        if let lat = trip.destinationLatitude, let lng = trip.destinationLongitude {
            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        return points
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
                                    colors: [Color.appOrange, Color.appDeepOrange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text(driverMember?.initials ?? "D")
                                    .font(SierraFont.title2)
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
                                        .fill(member.availability == .available ? Color.statusActive : .gray)
                                        .frame(width: 8, height: 8)
                                    Text(member.availability.rawValue.capitalized)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(member.availability == .available ? Color.statusActive : .secondary)
                                }
                                .accessibilityLabel("Availability \(member.availability.rawValue.capitalized)")
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }

                // Stats
                Section("Trip Statistics") {
                    HStack {
                        Label("Completed Trips", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                        Spacer()
                        Text("\(completedTrips)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appOrange)
                    }
                    .accessibilityElement(children: .combine)
                    HStack {
                        Label("Total Distance", systemImage: "road.lanes")
                            .font(.subheadline)
                        Spacer()
                        Text("\(totalDistanceKm) km")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appOrange)
                    }
                    .accessibilityElement(children: .combine)
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
                        .accessibilityElement(children: .combine)
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
                        .accessibilityElement(children: .combine)
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
                                .font(SierraFont.monoSM.weight(.semibold))
                                .foregroundStyle(Color.appOrange)
                        }
                        .accessibilityElement(children: .combine)
                        HStack {
                            Label("Class", systemImage: "creditcard.fill")
                                .font(.subheadline)
                            Spacer()
                            Text(profile.licenseClass)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        HStack {
                            Label("Issuing State", systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                            Spacer()
                            Text(profile.licenseIssuingState)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        HStack {
                            Label("Expiry", systemImage: "calendar.badge.clock")
                                .font(.subheadline)
                            Spacer()
                            Text(profile.licenseExpiry)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }

                    Section("Documents") {
                        HStack {
                            Label("License Doc", systemImage: "doc.richtext.fill")
                                .font(.subheadline)
                            Spacer()
                            Text(profile.licenseDocumentUrl != nil ? "Uploaded ✓" : "Not uploaded")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(profile.licenseDocumentUrl != nil ? Color.statusActive : .secondary)
                        }
                        .accessibilityElement(children: .combine)
                        HStack {
                            Label("Aadhaar Card", systemImage: "person.text.rectangle.fill")
                                .font(.subheadline)
                            Spacer()
                            Text(profile.aadhaarDocumentUrl != nil ? "Uploaded ✓" : "Not uploaded")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(profile.aadhaarDocumentUrl != nil ? Color.statusActive : .secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                // Security
                Section("Security") {
                    Toggle(isOn: $isBiometricEnabled) {
                        Label(biometricLabel, systemImage: biometricIcon)
                            .font(.subheadline)
                    }
                    .tint(Color.appOrange)
                    .disabled(!biometric.canUseBiometrics())
                    // FIX: do NOT trigger a biometric challenge just to SET the preference.
                    // The challenge happens at sign-in time, not at settings-change time.
                    // Previously this called BiometricAuthManager.authenticate() which
                    // silently reverted the toggle to false on any Face ID failure —
                    // making it impossible to enable biometrics. Match AdminProfileView.
                    .onChange(of: isBiometricEnabled) { _, enabled in
                        BiometricPreference.isEnabled = enabled
                    }
                    .accessibilityLabel("\(biometricLabel) login")
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

                    Text("High-contrast colors and stronger non-color cues are enabled when this is on.")
                        .font(SierraFont.caption1)
                        .foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                }

                // Sign Out
                Section {
                    Button(role: .destructive) {
                        AuthManager.shared.signOut(clearBiometricEnrollment: true)
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
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") {
                        populateEditDraft()
                        showEditProfile = true
                    }
                    .font(SierraFont.headline)
                    .disabled(driverMember == nil)
                    .accessibilityLabel("Edit profile")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(SierraFont.headline)
                        .accessibilityLabel("Close profile")
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                Form {
                    Section("Contact") {
                        TextField("Full Name", text: $editName)
                            .textContentType(.name)
                        HStack(spacing: 8) {
                            Text("+91")
                                .foregroundStyle(.secondary)
                            TextField("Mobile Number", text: $editPhone)
                                .keyboardType(.numberPad)
                                .textContentType(.telephoneNumber)
                        }
                        TextField("Address", text: $editAddress, axis: .vertical)
                            .lineLimit(2...4)
                            .textContentType(.fullStreetAddress)
                    }

                    Section("Emergency Contact") {
                        TextField("Contact Name", text: $editEmergencyName)
                            .textContentType(.name)
                        HStack(spacing: 8) {
                            Text("+91")
                                .foregroundStyle(.secondary)
                            TextField("Contact Phone", text: $editEmergencyPhone)
                                .keyboardType(.numberPad)
                                .textContentType(.telephoneNumber)
                        }
                    }

                    Section("License") {
                        TextField("License Number", text: $editLicenseNumber)
                            .textInputAutocapitalization(.characters)
                        TextField("Class", text: $editLicenseClass)
                            .textInputAutocapitalization(.characters)
                        TextField("Issuing State", text: $editLicenseState)
                        TextField("Expiry (YYYY-MM-DD)", text: $editLicenseExpiry)
                            .keyboardType(.numbersAndPunctuation)
                    }

                    if !profileValidationErrors.isEmpty {
                        Section("Validation") {
                            ForEach(profileValidationErrors, id: \.self) { message in
                                Text(message)
                                    .font(SierraFont.footnote.weight(.semibold))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .onChange(of: editPhone) { _, newValue in
                    editPhone = Self.digitsOnly(newValue).prefix(10).description
                }
                .onChange(of: editEmergencyPhone) { _, newValue in
                    editEmergencyPhone = Self.digitsOnly(newValue).prefix(10).description
                }
                .onChange(of: editLicenseNumber) { _, newValue in
                    editLicenseNumber = Self.filteredUppercaseAlphanumericDash(newValue, maxLength: 20)
                }
                .onChange(of: editLicenseClass) { _, newValue in
                    editLicenseClass = Self.filteredUppercaseAlphanumericDash(newValue, maxLength: 10)
                }
                .navigationTitle("Edit Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showEditProfile = false }
                            .accessibilityLabel("Cancel editing profile")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await saveProfileChanges() }
                        } label: {
                            if isSavingProfile {
                                ProgressView()
                            } else {
                                Text("Save")
                            }
                        }
                        .disabled(!canSaveProfile)
                        .accessibilityLabel("Save profile changes")
                    }
                }
            }
        }
        .alert("Unable to Save", isPresented: .constant(saveErrorMessage != nil)) {
            Button("OK") { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "Something went wrong. Please try again.")
        }
        // Sync toggle when sheet re-appears
        .onAppear { isBiometricEnabled = BiometricPreference.isEnabled }
    }

    // MARK: - Edit Profile

    private func populateEditDraft() {
        guard let member = driverMember else { return }
        let profile = store.driverProfile(for: member.id)

        editName = member.name ?? ""
        editPhone = Self.indianMobileDigits(from: member.phone)
        editAddress = member.address ?? ""
        editEmergencyName = member.emergencyContactName ?? ""
        editEmergencyPhone = Self.indianMobileDigits(from: member.emergencyContactPhone)

        editLicenseNumber = profile?.licenseNumber ?? ""
        editLicenseClass = profile?.licenseClass ?? ""
        editLicenseState = profile?.licenseIssuingState ?? ""
        editLicenseExpiry = profile?.licenseExpiry ?? ""
    }

    @MainActor
    private func saveProfileChanges() async {
        guard let member = driverMember else {
            saveErrorMessage = "Driver profile is unavailable."
            return
        }

        func trimmed(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard profileValidationErrors.isEmpty else {
            saveErrorMessage = profileValidationErrors.first
            return
        }

        isSavingProfile = true
        defer { isSavingProfile = false }

        do {
            var updatedMember = member
            let oldMember = member
            let oldProfile = store.driverProfile(for: member.id)

            updatedMember.name = trimmed(editName).isEmpty ? nil : trimmed(editName)
            updatedMember.phone = trimmed(editPhone).isEmpty ? nil : "+91\(trimmed(editPhone))"
            updatedMember.address = trimmed(editAddress).isEmpty ? nil : trimmed(editAddress)
            updatedMember.emergencyContactName = trimmed(editEmergencyName).isEmpty ? nil : trimmed(editEmergencyName)
            updatedMember.emergencyContactPhone = trimmed(editEmergencyPhone).isEmpty ? nil : "+91\(trimmed(editEmergencyPhone))"

            let memberChanged =
                oldMember.name != updatedMember.name
                || oldMember.phone != updatedMember.phone
                || oldMember.address != updatedMember.address
                || oldMember.emergencyContactName != updatedMember.emergencyContactName
                || oldMember.emergencyContactPhone != updatedMember.emergencyContactPhone

            if memberChanged {
                try await store.updateStaffMember(updatedMember)
            }

            var profileChanged = false
            if var profile = oldProfile {
                let original = profile
                profile.licenseNumber = trimmed(editLicenseNumber).uppercased()
                profile.licenseClass = trimmed(editLicenseClass).uppercased()
                profile.licenseIssuingState = trimmed(editLicenseState)
                profile.licenseExpiry = trimmed(editLicenseExpiry)

                profileChanged =
                    original.licenseNumber != profile.licenseNumber
                    || original.licenseClass != profile.licenseClass
                    || original.licenseIssuingState != profile.licenseIssuingState
                    || original.licenseExpiry != profile.licenseExpiry

                if profileChanged {
                    try await store.updateDriverProfile(profile)
                }
            }

            guard memberChanged || profileChanged else {
                showEditProfile = false
                return
            }

            let who = updatedMember.displayName
            let what = profileChanged && memberChanged
                ? "contact and license details"
                : (profileChanged ? "license details" : "contact details")

            await NotificationService.sendToAdmins(
                type: .general,
                title: "Driver Profile Updated",
                body: "\(who) updated \(what).",
                entityType: "staff_member",
                entityId: updatedMember.id
            )

            showEditProfile = false
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private static func digitsOnly(_ value: String) -> String {
        value.filter(\.isNumber)
    }

    private static func indianMobileDigits(from value: String?) -> String {
        let digits = digitsOnly(value ?? "")
        if digits.count >= 10 { return String(digits.suffix(10)) }
        return digits
    }

    private static func filteredUppercaseAlphanumericDash(_ value: String, maxLength: Int) -> String {
        let filtered = value.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return String(filtered.prefix(maxLength))
    }

    private static func isValidDateYYYYMMDD(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        return formatter.date(from: value) != nil
    }

    private static func isFutureOrTodayDateYYYYMMDD(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        guard let expiryDate = formatter.date(from: value) else { return false }
        let todayStart = Calendar.current.startOfDay(for: Date())
        let expiryStart = Calendar.current.startOfDay(for: expiryDate)
        return expiryStart >= todayStart
    }
}

#Preview {
    DriverProfileSheet()
        .environment(AppDataStore.shared)
        .environment(AccessibilitySettings.shared)
}
