import SwiftUI
import CoreLocation

/// Full-screen SOS alert sheet — emergency red background.
/// Safeguard 1: alertSent guard prevents duplicate submissions.
/// Safeguard 2: GPS validated before submission.
struct SOSAlertSheet: View {

    let tripId: UUID?
    let vehicleId: UUID?
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var alertType: EmergencyAlertType = .sos
    @State private var descriptionText = ""
    @State private var isSending = false
    @State private var alertSent = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var gpsRetryCount = 0

    private let locationManager = CLLocationManager()
    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    var body: some View {
        ZStack {
            // Emergency red background
            LinearGradient(colors: [Color.red.opacity(0.9), Color.red.opacity(0.7)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Cancel
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // SOS icon
                Image(systemName: "sos.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10)

                Text("Emergency Alert")
                    .font(.title.weight(.black))
                    .foregroundStyle(.white)

                // Alert type picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("ALERT TYPE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .kerning(1)

                    Picker("Type", selection: $alertType) {
                        ForEach(EmergencyAlertType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 24)

                // Description
                TextField("Describe the situation...", text: $descriptionText, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(12)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)

                // Confirmation
                if alertSent {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white)
                        Text("Alert Sent — Help is on the way")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                // Send button (Safeguard 1: once only)
                if !alertSent {
                    Button {
                        Task { await sendAlert() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSending {
                                ProgressView().tint(.red)
                            }
                            Text("SEND ALERT")
                                .font(.title3.weight(.black))
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    }
                    .disabled(alertSent || isSending)
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 40)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Send (Safeguards 1 + 2)

    private func sendAlert() async {
        guard !alertSent && !isSending else { return }
        isSending = true

        // Safeguard 2: GPS validation
        var latitude: Double = 0
        var longitude: Double = 0

        if let loc = locationManager.location,
           loc.coordinate.latitude != 0 || loc.coordinate.longitude != 0 {
            latitude = loc.coordinate.latitude
            longitude = loc.coordinate.longitude
        } else if gpsRetryCount < 5 {
            gpsRetryCount += 1
            isSending = false
            errorMessage = "Acquiring GPS location... Please wait and try again."
            showError = true
            return
        }
        // After 5 retries, allow submission with (0,0) but warn

        do {
            let alert = EmergencyAlert(
                id: UUID(),
                driverId: currentUserId,
                tripId: tripId,
                vehicleId: vehicleId,
                latitude: latitude,
                longitude: longitude,
                alertType: alertType,
                status: .active,
                description: descriptionText.isEmpty ? nil : descriptionText,
                acknowledgedBy: nil,
                acknowledgedAt: nil,
                resolvedAt: nil,
                triggeredAt: Date(),
                createdAt: Date()
            )

            try await EmergencyAlertService.addEmergencyAlert(alert)

            // Notify all fleet managers
            let fms = store.staff.filter { $0.role == .fleetManager }
            let notifType: NotificationType = (alertType == .defect) ? .defectAlert : .sosAlert
            for fm in fms {
                do {
                    try await NotificationService.insertNotification(
                        recipientId: fm.id,
                        type: notifType,
                        title: "\(alertType.rawValue) Alert",
                        body: "Driver emergency: \(alertType.rawValue)\(descriptionText.isEmpty ? "" : " — \(descriptionText)")",
                        entityType: "emergency_alert",
                        entityId: alert.id
                    )
                } catch {
                    print("[SOS] Non-fatal: notification to FM \(fm.id) failed")
                }
            }

            withAnimation { alertSent = true }

            // Dismiss after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            dismiss()

        } catch {
            isSending = false
            errorMessage = "Failed to send alert. Tap again to retry."
            showError = true
        }
    }
}
