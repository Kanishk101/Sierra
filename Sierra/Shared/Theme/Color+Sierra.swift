import SwiftUI

extension Color {
    /// Deprecated. Use system semantic colors (.primary, .secondary, .orange, .green, .red, .blue, etc.)
    @available(*, deprecated, message: "Use system semantic colors instead of Sierra tokens.")
    static func sierra(_ token: Color) -> Color { token }
}
