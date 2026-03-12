import SwiftUI

struct DriverOnboardingView: View {
    @State private var fullName: String = ""
    @State private var licenseNumber: String = ""
    @State private var phoneNumber: String = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)

                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.white.opacity(0.7))

                    Text("Complete Your Profile")
                        .font(SierraFont.title1)
                        .foregroundStyle(.white)

                    Text("Fill in your details to get started.")
                        .font(SierraFont.subheadline)
                        .foregroundStyle(.white.opacity(0.6))

                    VStack(spacing: 16) {
                        formField(placeholder: "Full Name", text: $fullName, icon: "person.fill")
                        formField(placeholder: "License Number", text: $licenseNumber, icon: "creditcard.fill")
                        formField(placeholder: "Phone Number", text: $phoneNumber, icon: "phone.fill")

                        Button {
                            // Profile submission to be implemented with backend
                        } label: {
                            Text("Submit Profile")
                                .font(SierraFont.body(17, weight: .semibold))
                                .foregroundStyle(SierraTheme.Colors.primaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
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
                .font(SierraFont.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 20)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(SierraFont.bodyText)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    DriverOnboardingView()
}
