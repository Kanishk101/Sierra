import SwiftUI

// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

// MARK: - OTP Input View
// Renamed from SixDigitInputView — now supports any digit count.
// Supabase sends 8-digit OTP tokens by default.
// TwoFactorView passes digitCount: 8.

typealias SixDigitInputView = OTPInputView  // backward-compat alias

struct OTPInputView: View {

    @Binding var digits: [String]
    @Binding var focusedIndex: Int?
    var shakeCount: Int = 0
    var digitCount: Int = 8
    var onComplete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<digitCount, id: \.self) { index in
                SingleDigitField(
                    text: Binding(
                        get: { index < digits.count ? digits[index] : "" },
                        set: { newValue in handleInput(newValue, at: index) }
                    ),
                    isFocused: focusedIndex == index,
                    onTap: { focusedIndex = index },
                    onBackspace: { handleBackspace(at: index) },
                    onPaste: { handlePaste($0, startingAt: index) }
                )
            }
        }
        .modifier(ShakeEffect(animatableData: CGFloat(shakeCount)))
    }

    // MARK: - Input Handling

    private func handleInput(_ value: String, at index: Int) {
        let filtered = value.filter { $0.isNumber }
        guard let lastChar = filtered.last else { return }
        guard index < digits.count else { return }
        digits[index] = String(lastChar)

        if index < digitCount - 1 {
            focusedIndex = index + 1
        } else {
            focusedIndex = nil
            let code = digits.joined()
            if code.count == digitCount { onComplete() }
        }
    }

    private func handleBackspace(at index: Int) {
        guard index < digits.count else { return }
        if digits[index].isEmpty && index > 0 {
            focusedIndex = index - 1
            digits[index - 1] = ""
        } else {
            digits[index] = ""
        }
    }

    private func handlePaste(_ pastedDigits: String, startingAt startIndex: Int) {
        let chars = Array(pastedDigits.filter { $0.isNumber }.prefix(digitCount))
        for (offset, char) in chars.enumerated() {
            guard offset < digits.count else { break }
            digits[offset] = String(char)
        }
        let filledCount = min(chars.count, digitCount)
        if filledCount == digitCount {
            focusedIndex = nil
            onComplete()
        } else {
            focusedIndex = filledCount
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
        .frame(width: 38, height: 50)
        .multilineTextAlignment(.center)
        .font(.system(size: 20, weight: .bold, design: .rounded))
        .foregroundStyle(SierraTheme.Colors.primaryText)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isFocused ? SierraTheme.Colors.ember : Color.gray.opacity(0.25),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .shadow(
            color: isFocused ? SierraTheme.Colors.ember.opacity(0.15) : .clear,
            radius: 6, y: 2
        )
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
        tf.textAlignment = .center
        tf.font = .systemFont(ofSize: 20, weight: .bold)
        tf.delegate = context.coordinator
        tf.onBackspace = onBackspace
        tf.textColor = UIColor(SierraTheme.Colors.primaryText)
        tf.tintColor = UIColor(SierraTheme.Colors.ember)
        return tf
    }

    func updateUIView(_ uiView: BackspaceTextField, context: Context) {
        if uiView.text != text { uiView.text = text }
        if isFocused && !uiView.isFirstResponder {
            DispatchQueue.main.async { uiView.becomeFirstResponder() }
        } else if !isFocused && uiView.isFirstResponder {
            DispatchQueue.main.async { uiView.resignFirstResponder() }
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
        @State private var digits = Array(repeating: "", count: 8)
        @State private var focused: Int? = 0
        @State private var shakes = 0

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    OTPInputView(
                        digits: $digits,
                        focusedIndex: $focused,
                        shakeCount: shakes,
                        digitCount: 8,
                        onComplete: { shakes += 1 }
                    )
                    Button("Shake") { withAnimation(.default) { shakes += 1 } }
                        .foregroundStyle(.white)
                }
                .padding()
            }
        }
    }
    return DemoView()
}
