import SwiftUI

// MARK: - Six Digit Input

/// Reusable 6-digit OTP input used by TwoFactorView.
/// Supabase is configured to send 6-digit OTP tokens (set in Auth > Settings > OTP length).
struct SixDigitInputView: View {

    @Binding var digits: [String] // must have exactly 6 elements
    @Binding var focusedIndex: Int?
    var onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { index in
                SingleDigitField(
                    text: Binding(
                        get: { digits[index] },
                        set: { newValue in handleInput(newValue, at: index) }
                    ),
                    isFocused: focusedIndex == index,
                    onTap: { 
                        withAnimation(.spring(duration: 0.2)) {
                            focusedIndex = index 
                        }
                    },
                    onBackspace: { handleBackspace(at: index) },
                    onPaste: { handlePaste($0, startingAt: index) }
                )
                .accessibilityLabel("Digit \(index + 1)")
                .accessibilityValue(digits[index].isEmpty ? "Empty" : digits[index])
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input Handling

    private func handleInput(_ value: String, at index: Int) {
        let filtered = value.filter { $0.isNumber }
        guard let lastChar = filtered.last else { return }
        digits[index] = String(lastChar)

        if index < 5 {
            focusedIndex = index + 1
        } else {
            focusedIndex = nil
            let code = digits.joined()
            if code.count == 6 { onComplete() }
        }
    }

    private func handleBackspace(at index: Int) {
        if digits[index].isEmpty && index > 0 {
            focusedIndex = index - 1
            digits[index - 1] = ""
        } else {
            digits[index] = ""
        }
    }

    private func handlePaste(_ pastedDigits: String, startingAt startIndex: Int) {
        let chars = Array(pastedDigits.filter { $0.isNumber }.prefix(6))
        for (offset, char) in chars.enumerated() {
            let idx = startIndex + offset
            guard idx < 6 else { break }
            digits[idx] = String(char)
        }
        let nextIndex = min(startIndex + chars.count, 6)
        if nextIndex == 6 {
            focusedIndex = nil
            onComplete()
        } else {
            focusedIndex = nextIndex
        }
    }
}

// MARK: - Single Digit Field

struct SingleDigitField: View {

    @Binding var text: String
    let isFocused: Bool
    let onTap: () -> Void
    let onBackspace: () -> Void
    var onPaste: ((String) -> Void)? = nil

    var body: some View {
        BackspaceDetectingTextField(
            text: $text,
            isFocused: isFocused,
            onBackspace: onBackspace,
            onPaste: onPaste
        )
        .frame(width: 48, height: 64)
        .multilineTextAlignment(.center)
        .font(SierraFont.body(28, weight: .bold))
        .foregroundStyle(SierraTheme.Colors.primaryText)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(
                    isFocused ? SierraTheme.Colors.ember : SierraTheme.Colors.cloud.opacity(0.8),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .sierraShadow(isFocused ? SierraShadow(color: SierraTheme.Colors.ember.opacity(0.12), radius: 8, x: 0, y: 3) : SierraShadow(color: .clear, radius: 0, x: 0, y: 0))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Backspace-Detecting TextField (UIKit wrapper)

struct BackspaceDetectingTextField: UIViewRepresentable {

    @Binding var text: String
    var isFocused: Bool
    var onBackspace: () -> Void
    var onPaste: ((String) -> Void)?

    func makeUIView(context: Context) -> BackspaceTextField {
        let tf = BackspaceTextField()
        tf.keyboardType = .numberPad
        tf.textContentType = .oneTimeCode
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.smartInsertDeleteType = .no
        tf.smartDashesType = .no
        tf.smartQuotesType = .no
        tf.autocapitalizationType = .none
        tf.textAlignment = .center
        tf.font = .systemFont(ofSize: 26, weight: .bold)
        tf.delegate = context.coordinator
        tf.onBackspace = onBackspace
        tf.textColor = UIColor(SierraTheme.Colors.primaryText)
        tf.tintColor = UIColor(SierraTheme.Colors.ember)
        return tf
    }

    func updateUIView(_ uiView: BackspaceTextField, context: Context) {
        if uiView.text != text { uiView.text = text }
        if isFocused {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
        uiView.onBackspace = onBackspace
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: BackspaceDetectingTextField
        init(_ parent: BackspaceDetectingTextField) { self.parent = parent }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                        replacementString string: String) -> Bool {
            if string.isEmpty { return true }
            let digits = string.filter { $0.isNumber }
            if digits.count > 1 {
                parent.onPaste?(digits)
                return false
            }
            guard digits.count == 1 else { return false }
            parent.text = digits
            return false
        }
    }
}

class BackspaceTextField: UITextField {
    var onBackspace: (() -> Void)?

    override func deleteBackward() {
        if text?.isEmpty == true { onBackspace?() }
        super.deleteBackward()
    }
}

#Preview {
    struct DemoView: View {
        @State private var digits = Array(repeating: "", count: 6)
        @State private var focused: Int? = 0

        var body: some View {
            VStack(spacing: 24) {
                SixDigitInputView(
                    digits: $digits,
                    focusedIndex: $focused,
                    onComplete: { }
                )
            }
            .padding()
        }
    }
    return DemoView()
}
