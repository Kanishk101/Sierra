import SwiftUI

// MARK: - initialsCircle
// Shared helper used across FleetManager views (StaffReviewSheet, PendingApprovalsView, etc.)
// to render a coloured circle with 1–2 initials letters inside it.

func initialsCircle(_ text: String, size: CGFloat, bg: Color) -> some View {
    Text(text)
        .font(SierraFont.scaled(size * 0.38, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(bg, in: Circle())
}
