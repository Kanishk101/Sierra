import SwiftUI

struct DriverOnboardingView: View {
    @State private var fullName: String = ""
    @State private var licenseNumber: String = ""
    @State private var phoneNumber: String = ""

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)

                    Image(systemName: "person.text.rectangle.fill")
                        .font(SierraFont.scaled(56, weight: .light))
                        .foregroundStyle(.orange)

                    Text("Complete Your Profile")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Fill in your details to get started.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 16) {
                        formField(placeholder: "Full Name", text: $fullName, icon: "person.fill")
                        formField(placeholder: "License Number", text: $licenseNumber, icon: "creditcard.fill")
                        formField(placeholder: "Phone Number", text: $phoneNumber, icon: "phone.fill")

                        Button {
                            // Profile submission to be implemented with backend
                        } label: {
                            Text("Submit Profile")
                                .font(SierraFont.scaled(17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 60)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func formField(placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 1)
        )
    }
}

#Preview {
    DriverOnboardingView()
}
