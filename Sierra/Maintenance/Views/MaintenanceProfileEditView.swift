import SwiftUI

/// Sheet for maintenance staff to edit their profile fields after onboarding.
struct MaintenanceProfileEditView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var emergencyContactName: String = ""
    @State private var emergencyContactPhone: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    var body: some View {
        Form {
            Section("Contact") {
                TextField("Phone Number", text: $phone)
                    .keyboardType(.phonePad)
                TextField("Address", text: $address, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Emergency Contact") {
                TextField("Contact Name", text: $emergencyContactName)
                TextField("Contact Phone", text: $emergencyContactPhone)
                    .keyboardType(.phonePad)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveProfile() }
                }
                .disabled(isSaving)
                .fontWeight(.semibold)
            }
        }
        .disabled(isSaving)
        .onAppear { loadCurrentValues() }
    }

    private func loadCurrentValues() {
        guard let member = store.staffMember(for: currentUserId) else { return }
        phone = member.phone ?? ""
        address = member.address ?? ""
        emergencyContactName = member.emergencyContactName ?? ""
        emergencyContactPhone = member.emergencyContactPhone ?? ""
    }

    private func saveProfile() async {
        guard var member = store.staffMember(for: currentUserId) else {
            errorMessage = "Could not find your profile."
            return
        }

        isSaving = true
        errorMessage = nil

        member.phone = phone.isEmpty ? nil : phone
        member.address = address.isEmpty ? nil : address
        member.emergencyContactName = emergencyContactName.isEmpty ? nil : emergencyContactName
        member.emergencyContactPhone = emergencyContactPhone.isEmpty ? nil : emergencyContactPhone

        do {
            try await store.updateStaffMember(member)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
