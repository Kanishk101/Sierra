import SwiftUI

struct QuickActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateStaff = false
    @State private var showAddVehicle = false
    @State private var showCreateTrip = false

    private struct QuickAction: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let color: Color
        let tag: String
    }

    private let actions: [QuickAction] = [
        QuickAction(icon: "shippingbox.fill", label: "Create Delivery Task", color: SierraTheme.Colors.info, tag: "delivery"),
        QuickAction(icon: "car.badge.gearshape", label: "Add Vehicle", color: SierraTheme.Colors.alpineMint, tag: "vehicle"),
        QuickAction(icon: "wrench.and.screwdriver.fill", label: "Create Maintenance Request", color: SierraTheme.Colors.ember, tag: "maintenance"),
        QuickAction(icon: "person.badge.plus", label: "Add Staff Member", color: SierraTheme.Colors.sierraBlue, tag: "staff"),
    ]

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Drag indicator
            Capsule()
                .fill(SierraTheme.Colors.mist)
                .frame(width: 36, height: 5)
                .padding(.top, Spacing.sm)

            Text("Quick Actions")
                .font(SierraFont.title3)
                .foregroundStyle(SierraTheme.Colors.primaryText)
                .padding(.top, Spacing.xxs)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)], spacing: Spacing.md) {
                ForEach(actions) { action in
                    Button {
                        switch action.tag {
                        case "staff":    showCreateStaff = true
                        case "vehicle":  showAddVehicle = true
                        case "delivery": showCreateTrip = true
                        default:         dismiss()
                        }
                    } label: {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: action.icon)
                                .font(.system(size: 26, weight: .light))
                                .foregroundStyle(action.color)
                                .frame(width: 52, height: 52)
                                .background(action.color.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))

                            Text(action.label)
                                .font(SierraFont.caption1)
                                .foregroundStyle(SierraTheme.Colors.primaryText)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.lg)
                        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                                .strokeBorder(SierraTheme.Colors.cloud, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
        .sheet(isPresented: $showCreateStaff) {
            CreateStaffView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showAddVehicle) {
            AddVehicleView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView()
                .presentationDetents([.large])
        }
    }
}

#Preview {
    QuickActionsSheet()
}
