import SwiftUI

// MARK: - Color + Sierra Extensions

extension Color {

    /// Semantic pass-through for Sierra design tokens.
    /// Usage: `.foregroundStyle(.sierra(.ember))`
    static func sierra(_ token: Color) -> Color { token }
}
