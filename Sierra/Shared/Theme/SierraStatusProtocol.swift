import SwiftUI

// MARK: - SierraStatus Protocol

/// Protocol adopted by all status enums in the Sierra brand kit.
/// Provides color, label, and display metadata so the universal `SierraBadge`
/// component can render any status without case-specific knowledge.
protocol SierraStatus {
    /// Human-readable label displayed in the badge (e.g. "Active", "On Trip").
    var label: String { get }
    /// Filled circle / left-dot color.
    var dotColor: Color { get }
    /// Semi-transparent background fill for the badge capsule.
    var backgroundColor: Color { get }
    /// Text (and icon) color inside the badge.
    var foregroundColor: Color { get }
    /// Optional SF Symbol name rendered before the label.
    var icon: String? { get }
    /// Whether to render the ● dot prefix. Defaults to `true`.
    var showsDot: Bool { get }
}

// MARK: - Default Implementations

extension SierraStatus {
    var icon: String? { nil }
    var showsDot: Bool { true }
}
