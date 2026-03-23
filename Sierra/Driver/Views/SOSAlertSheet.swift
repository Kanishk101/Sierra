import SwiftUI
import CoreLocation

/// Full-screen SOS alert sheet — emergency red background.
/// Safeguard 1: alertSent guard prevents duplicate submissions.
/// Safeguard 2: GPS validated before submission.
struct SOSAlertSheet: View {

    let tripId: UUID?
    let vehicleId: UUID?
    let currentLocation: CLLocation?  // BUG-03 FIX: passed from coordinator
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var vm = SOSAlertViewModel()

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
                alertTypePicker

                // Description
                descriptionField

                // Confirmation
                if vm.sentSuccessfully {
                    confirmationView
                }

                Spacer()

                // Send button (Safeguard 1: once only)
                if !vm.sentSuccessfully {
                    sendButton
                }

                Spacer(minLength: 40)
            }
        }
        .alert("Error", isPresented: .constant(vm.error != nil)) {
            Button("OK") { vm.error = nil }
        } message: {
            Text(vm.error ?? "Something went wrong")
        }
    }

    // MARK: - Subviews

    private var alertTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALERT TYPE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
                .kerning(1)

            Picker("Type", selection: $vm.alertType) {
                ForEach(EmergencyAlertType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 24)
    }

    private var descriptionField: some View {
        TextField("Describe the situation...", text: $vm.descriptionText, axis: .vertical)
            .lineLimit(3...5)
            .padding(12)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
    }

    private var confirmationView: some View {
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

    private var sendButton: some View {
        Button {
            Task {
                await vm.triggerSOS(vehicleId: vehicleId, tripId: tripId, store: store, currentLocation: currentLocation)
                if vm.sentSuccessfully {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if vm.isSending {
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
        .disabled(vm.sentSuccessfully || vm.isSending)
        .padding(.horizontal, 24)
    }
}
