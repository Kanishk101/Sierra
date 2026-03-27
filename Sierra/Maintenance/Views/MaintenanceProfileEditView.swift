import SwiftUI

/// Edit profile fields for maintenance staff in Sierra card style.
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
        ScrollView {
            VStack(spacing: 14) {
                sectionCard(title: "Contact") {
                    field(label: "Phone Number", text: $phone, keyboard: .phonePad, icon: "phone.fill")
                    field(label: "Address", text: $address, keyboard: .default, icon: "house.fill")
                }

                sectionCard(title: "Emergency Contact") {
                    field(label: "Contact Name", text: $emergencyContactName, keyboard: .default, icon: "person.crop.circle.badge.exclamationmark")
                    field(label: "Contact Phone", text: $emergencyContactPhone, keyboard: .phonePad, icon: "phone.badge.waveform.fill")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 34)
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.appTextSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await saveProfile() }
                }
                .disabled(isSaving)
                .foregroundStyle(Color.appOrange)
                .fontWeight(.bold)
            }
        }
        .disabled(isSaving)
        .onAppear { loadCurrentValues() }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(SierraFont.scaled(14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)

            VStack(spacing: 10) {
                content()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appCardBg)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }

    private func field(label: String, text: Binding<String>, keyboard: UIKeyboardType, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(SierraFont.scaled(13, weight: .semibold))
                .foregroundStyle(Color.appOrange)
                .frame(width: 16)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .font(SierraFont.scaled(14, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appDivider.opacity(0.6), lineWidth: 1))
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
