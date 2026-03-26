import SwiftUI

// MARK: - SierraTextField Style

enum SierraTextFieldStyle {
    /// White bg, mist border, ember on focus.
    case `default`
    /// Snowfield bg, no border, bottom ember line on focus.
    case filled
    /// Transparent, bottom border only.
    case ghost
    /// Inset gray background, no border, higher radius (iOS Native style).
    case native
}

// MARK: - SierraTextField

/// Branded text field with label, icon, error state, mono mode, and three visual styles.
///
///     SierraTextField(label: "VIN Number", placeholder: "Enter VIN",
///                     text: $vin, isMonoFont: true, isRequired: true)
struct SierraTextField: View {

    let label: String
    let placeholder: String
    @Binding var text: String
    var style: SierraTextFieldStyle = .default
    var keyboardType: UIKeyboardType = .default
    var isMonoFont: Bool = false
    var leadingIcon: String? = nil
    var trailingContent: AnyView? = nil
    var errorMessage: String? = nil
    var isRequired: Bool = false
    var isDisabled: Bool = false
    var isSecure: Bool = false
    var maxLength: Int? = nil
    var filterDigitsOnly: Bool = false

    @FocusState private var isFocused: Bool
    @State private var isPasswordVisible: Bool = false

    /// A wrapped binding that enforces the character limit and digit-only filtering.
    private var filteredText: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                var filtered = newValue
                if filterDigitsOnly {
                    filtered = filtered.filter { $0.isNumber }
                }
                if let limit = maxLength {
                    text = String(filtered.prefix(limit))
                } else {
                    text = filtered
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {

            // ── Label ──
            if !label.isEmpty {
                Text(label + (isRequired ? " *" : ""))
                    .font(SierraFont.caption1)
                    .foregroundStyle(isFocused ? SierraTheme.Colors.ember : SierraTheme.Colors.granite)
                    .padding(.leading, style == .native ? 4 : 0)
            }

            // ── Field Container ──
            HStack(spacing: Spacing.xs) {
                if let leadingIcon {
                    Image(systemName: leadingIcon)
                        .font(.system(size: 15))
                        .foregroundStyle(isFocused ? SierraTheme.Colors.ember : SierraTheme.Colors.granite)
                }

                Group {
                    if isSecure && !isPasswordVisible {
                        SecureField(placeholder, text: filteredText)
                    } else {
                        TextField(placeholder, text: filteredText)
                    }
                }
                .font(isMonoFont ? SierraFont.mono(15, weight: .regular) : SierraFont.bodyText)
                .foregroundStyle(isDisabled ? SierraTheme.Colors.granite : SierraTheme.Colors.primaryText)
                .keyboardType(keyboardType)
                .focused($isFocused)
                .disabled(isDisabled)
                .textInputAutocapitalization(isSecure ? .none : .sentences)
                .autocorrectionDisabled(isSecure)

                if isSecure {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(SierraTheme.Colors.granite)
                    }
                    .buttonStyle(.plain)
                }

                if let trailingContent {
                    trailingContent
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: 48)
            .background(fieldBackground, in: fieldShape)
            .overlay { fieldBorder }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isDisabled else { return }
                isFocused = true
            }

            // ── Error Message ──
            if let errorMessage {
                Text(errorMessage)
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.danger)
                    .padding(.leading, Spacing.xxs)
            }
        }
    }

    // MARK: - Style-Dependent Visuals

    private var fieldBackground: Color {
        if isDisabled { return SierraTheme.Colors.cloud.opacity(0.4) }
        switch style {
        case .default: return SierraTheme.Colors.cardSurface
        case .filled:  return SierraTheme.Colors.snowfield
        case .ghost:   return .clear
        case .native:  return Color(.secondarySystemGroupedBackground)
        }
    }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: style == .native ? Radius.xl : Radius.md, style: .continuous)
    }

    @ViewBuilder
    private var fieldBorder: some View {
        switch style {
        case .default:
            fieldShape
                .strokeBorder(borderColor, lineWidth: 1.5)
        case .filled:
            VStack { Spacer(); Rectangle().fill(isFocused ? SierraTheme.Colors.ember : .clear).frame(height: 2) }
        case .ghost:
            VStack { Spacer(); Rectangle().fill(borderColor).frame(height: 1) }
        case .native:
            EmptyView()
        }
    }

    private var borderColor: Color {
        if errorMessage != nil { return SierraTheme.Colors.danger }
        if isFocused { return SierraTheme.Colors.ember }
        return SierraTheme.Colors.mist
    }
}
