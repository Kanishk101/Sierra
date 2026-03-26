import SwiftUI
import UIKit

// MARK: - Six Digit Input

/// Reusable 6-digit OTP input used by TwoFactorView / ForgotPasswordView.
/// Uses a single hidden UITextField to avoid keyboard bounce when moving focus between boxes.
struct SixDigitInputView: View {

    @Binding var digits: [String] // must have exactly 6 elements
    @Binding var focusedIndex: Int?
    var onComplete: () -> Void

    @State private var code: String = ""
    @State private var lastAutoSubmittedCode: String?

    private var isKeyboardActive: Binding<Bool> {
        Binding(
            get: { focusedIndex != nil },
            set: { active in
                if !active { focusedIndex = nil }
            }
        )
    }

    var body: some View {
        ZStack {
            OTPHiddenTextField(
                text: $code,
                cursorIndex: Binding(
                    get: { focusedIndex ?? max(0, min(code.count, 6)) },
                    set: { focusedIndex = max(0, min($0, 6)) }
                ),
                isFirstResponder: isKeyboardActive
            )
            .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
            .opacity(0.015)

            // Keep boxes visual-only so native UITextField interactions
            // (OTP autofill/paste/select) work reliably.
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    otpBox(at: index)
                        .accessibilityLabel("Digit \(index + 1)")
                        .accessibilityValue(character(at: index).isEmpty ? "Empty" : character(at: index))
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                focusedIndex = max(0, min(code.count, 6))
            }
        )
        .onAppear {
            code = sanitizedCode(from: digits.joined())
            if focusedIndex == nil {
                focusedIndex = max(0, min(code.count, 6))
            }
        }
        .onChange(of: digits) { _, newDigits in
            let fromDigits = sanitizedCode(from: newDigits.joined())
            if fromDigits != code {
                code = fromDigits
            }
        }
        .onChange(of: code) { _, newValue in
            let sanitized = sanitizedCode(from: newValue)
            if sanitized != newValue {
                code = sanitized
                return
            }
            syncDigitsFromCode(sanitized)
        }
    }

    private func otpBox(at index: Int) -> some View {
        let char = character(at: index)
        let activeIndex = focusedIndex.map { max(0, min($0, 5)) } ?? max(0, min(code.count, 5))
        let isActive = activeIndex == index

        return ZStack {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))

            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(
                    isActive ? SierraTheme.Colors.ember : SierraTheme.Colors.cloud.opacity(0.8),
                    lineWidth: isActive ? 2 : 1
                )

            Text(char)
                .font(SierraFont.body(28, weight: .bold))
                .foregroundStyle(SierraTheme.Colors.primaryText)
                .monospacedDigit()
        }
        .frame(width: 48, height: 64)
        .sierraShadow(isActive
            ? SierraShadow(color: SierraTheme.Colors.ember.opacity(0.12), radius: 8, x: 0, y: 3)
            : SierraShadow(color: .clear, radius: 0, x: 0, y: 0)
        )
        .animation(.easeOut(duration: 0.14), value: code)
        .animation(.easeOut(duration: 0.14), value: focusedIndex)
    }

    private func character(at index: Int) -> String {
        guard index < code.count else { return "" }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[stringIndex])
    }

    private func focusAt(_ index: Int) {
        // Keep cursor movement stable and avoid mutating text just by tapping.
        focusedIndex = max(0, min(index, code.count))
    }

    private func syncDigitsFromCode(_ value: String) {
        var next = Array(repeating: "", count: 6)
        for (i, c) in value.enumerated() where i < 6 {
            next[i] = String(c)
        }

        let nextFocus = max(0, min(value.count, 6))

        if digits != next {
            digits = next
        }
        if focusedIndex != nextFocus {
            focusedIndex = nextFocus
        }

        if value.count == 6, lastAutoSubmittedCode != value {
            lastAutoSubmittedCode = value
            onComplete()
        } else if value.count < 6 {
            lastAutoSubmittedCode = nil
        }
    }

    private func sanitizedCode(from raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(6))
    }
}

// MARK: - Hidden OTP UITextField

private struct OTPHiddenTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorIndex: Int
    @Binding var isFirstResponder: Bool

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.keyboardType = .numberPad
        tf.textContentType = .oneTimeCode
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.smartInsertDeleteType = .no
        tf.smartDashesType = .no
        tf.smartQuotesType = .no
        tf.autocapitalizationType = .none
        tf.tintColor = UIColor.clear
        tf.textColor = .clear
        tf.delegate = context.coordinator
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        context.coordinator.setCursorIfNeeded(in: uiView, index: cursorIndex, textCount: text.count)

        if isFirstResponder {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: OTPHiddenTextField

        init(_ parent: OTPHiddenTextField) {
            self.parent = parent
        }

        private func commit(text: String, cursorIndex: Int) {
            let boundedCursor = max(0, min(cursorIndex, text.count))
            if parent.text != text {
                parent.text = text
            }
            if parent.cursorIndex != boundedCursor {
                parent.cursorIndex = boundedCursor
            }
        }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            guard let current = textField.text,
                  let swiftRange = Range(range, in: current) else {
                return false
            }

            // Native paste / OTP autofill can provide multiple digits at once.
            // Apply at current cursor/range so edit behavior matches UITextField semantics.
            let pastedDigits = string.filter(\.isNumber)
            if pastedDigits.count > 1 {
                let updated = current.replacingCharacters(in: swiftRange, with: pastedDigits)
                let digitsOnly = String(updated.filter(\.isNumber).prefix(6))
                let cursor = max(0, min(range.location + pastedDigits.count, digitsOnly.count))
                commit(text: digitsOnly, cursorIndex: cursor)
                return false
            }

            // Number pad backspace on hidden fields can report 0-length deletes.
            // Delete the character immediately before cursor in that case.
            if string.isEmpty, range.length == 0, range.location > 0, !current.isEmpty {
                let deleteLocation = max(0, min(range.location, current.count) - 1)
                guard let deleteStart = current.index(current.startIndex, offsetBy: deleteLocation, limitedBy: current.endIndex),
                      let deleteEnd = current.index(deleteStart, offsetBy: 1, limitedBy: current.endIndex) else {
                    return false
                }
                let updated = current.replacingCharacters(in: deleteStart..<deleteEnd, with: "")
                let digitsOnly = String(updated.filter { $0.isNumber }.prefix(6))
                commit(text: digitsOnly, cursorIndex: deleteLocation)
                return false
            }

            // Overwrite mode: typing into a filled position should replace that digit,
            // not shift the remaining code to the right.
            if pastedDigits.count == 1, range.length == 0, range.location < current.count {
                guard let start = current.index(current.startIndex, offsetBy: range.location, limitedBy: current.endIndex),
                      let end = current.index(start, offsetBy: 1, limitedBy: current.endIndex) else {
                    return false
                }
                let updated = current.replacingCharacters(in: start..<end, with: String(pastedDigits))
                let digitsOnly = String(updated.filter(\.isNumber).prefix(6))
                commit(text: digitsOnly, cursorIndex: min(range.location + 1, digitsOnly.count))
                return false
            }

            // Ignore non-digit single-key input.
            if !string.isEmpty && pastedDigits.isEmpty {
                return false
            }

            let updated = current.replacingCharacters(in: swiftRange, with: pastedDigits)
            let digitsOnly = String(updated.filter { $0.isNumber }.prefix(6))
            let newCursor = max(0, min(range.location + pastedDigits.count, digitsOnly.count))
            commit(text: digitsOnly, cursorIndex: newCursor)
            return false
        }

        func setCursorIfNeeded(in textField: UITextField, index: Int, textCount: Int) {
            let target = max(0, min(index, textCount))
            guard let start = textField.position(from: textField.beginningOfDocument, offset: target),
                  let selected = textField.selectedTextRange else { return }
            let currentOffset = textField.offset(from: textField.beginningOfDocument, to: selected.start)
            if currentOffset != target {
                textField.selectedTextRange = textField.textRange(from: start, to: start)
            }
        }
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
