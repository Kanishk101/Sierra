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
        VStack(spacing: 12) {
            // Strength bar
            strengthBar

            // Requirements checklist
            requirementsChecklist
        }
        .animation(.easeInOut(duration: 0.2), value: password)
    }

    // MARK: - Strength Bar

    private var strengthBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index <= strength.rawValue
                              ? strength.color : .white.opacity(0.1))
                        .frame(height: 5)
                }
            }

            HStack {
                Text(strength.label)
                    .font(SierraFont.caption2)
                    .foregroundStyle(strength.color)
                Spacer()
            }
        }
    }

    // MARK: - Requirements Checklist

    private var requirementsChecklist: some View {
        VStack(alignment: .leading, spacing: 6) {
            requirementRow("At least 8 characters", met: hasMinLength)
            requirementRow("One uppercase letter", met: hasUppercase)
            requirementRow("One number", met: hasNumber)
            requirementRow("One special character", met: hasSpecialChar)
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func requirementRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle")
                .font(SierraFont.caption1)
                .foregroundStyle(met ? .green : .white.opacity(0.3))

            Text(text)
                .font(SierraFont.caption1)
                .foregroundStyle(met ? .white.opacity(0.9) : .white.opacity(0.4))
        }
        .animation(.easeInOut(duration: 0.15), value: met)
    }
}

#Preview {
    ZStack {
        SierraTheme.Colors.summitNavy.ignoresSafeArea()
        PasswordStrengthView(password: "Test@12")
            .padding()
    }
}
