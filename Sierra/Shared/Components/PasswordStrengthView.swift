import SwiftUI

/// Reusable password strength indicator bar + requirements checklist.
/// Used by ForcePasswordChangeView and ForgotPasswordView.
struct PasswordStrengthView: View {

    let password: String

    // MARK: - Computed

    var strength: PasswordStrength {
        PasswordStrength.evaluate(password)
    }

    var hasMinLength: Bool { password.count >= 8 }
    var hasUppercase: Bool { password.range(of: "[A-Z]", options: .regularExpression) != nil }
    var hasNumber: Bool    { password.range(of: "[0-9]", options: .regularExpression) != nil }
    var hasSpecialChar: Bool { password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil }

    var allRequirementsMet: Bool {
        hasMinLength && hasUppercase && hasNumber && hasSpecialChar
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Strength bar
            strengthBar
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Password strength: \(strength.label)")

            // Requirements checklist
            requirementsChecklist
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: password)
    }

    // MARK: - Strength Bar

    private var strengthBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<4) { index in
                    let isActive = index <= strength.rawValue
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isActive ? strength.color : SierraTheme.Colors.cloud.opacity(0.4))
                        .frame(height: 6)
                        .scaleEffect(isActive ? 1.0 : 0.95)
                        .animation(.spring(duration: 0.3, bounce: 0.3).delay(Double(index) * 0.05), value: strength)
                }
            }

            HStack {
                Text(strength.label.uppercased())
                    .font(SierraFont.caption1.weight(.bold))
                    .foregroundStyle(strength.color)
                    .tracking(0.5)
                Spacer()
            }
        }
    }

    // MARK: - Requirements Checklist

    private var requirementsChecklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            requirementRow("At least 8 characters", met: hasMinLength)
            requirementRow("One uppercase letter", met: hasUppercase)
            requirementRow("One number", met: hasNumber)
            requirementRow("One special character", met: hasSpecialChar)
        }
        .padding(16)
        .background(
            SierraTheme.Colors.appBackground.opacity(0.5),
            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(SierraTheme.Colors.cloud.opacity(0.5), lineWidth: 1)
        )
    }

    private func requirementRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(met ? SierraTheme.Colors.alpineMint : SierraTheme.Colors.cloud, lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                
                if met {
                    Image(systemName: "checkmark")
                        .font(SierraFont.scaled(10, weight: .bold))
                        .foregroundStyle(SierraTheme.Colors.alpineMint)
                }
            }
            .accessibilityHidden(true)

            Text(text)
                .font(SierraFont.caption1)
                .foregroundStyle(met ? SierraTheme.Colors.primaryText : SierraTheme.Colors.secondaryText)
                .strikethrough(met, color: SierraTheme.Colors.alpineMint.opacity(0.3))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text): \(met ? "Met" : "Not met")")
        .animation(.easeInOut(duration: 0.25), value: met)
    }
}

#Preview {
    ZStack {
        SierraTheme.Colors.appBackground.ignoresSafeArea()
        PasswordStrengthView(password: "Test@12")
            .padding()
    }
}
