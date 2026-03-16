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
        QuickAction(icon: "shippingbox.fill", label: "Create Delivery Task", color: .blue, tag: "delivery"),
        QuickAction(icon: "car.badge.gearshape", label: "Add Vehicle", color: .green, tag: "vehicle"),
        QuickAction(icon: "wrench.and.screwdriver.fill", label: "Create Maintenance Request", color: .orange, tag: "maintenance"),
        QuickAction(icon: "person.badge.plus", label: "Add Staff Member", color: .indigo, tag: "staff"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Drag indicator
            Capsule()
                .fill(Color(.separator))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text("Quick Actions")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.top, 2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(actions) { action in
                    Button {
                        switch action.tag {
                        case "staff":    showCreateStaff = true
                        case "vehicle":  showAddVehicle = true
                        case "delivery": showCreateTrip = true
                        default:         dismiss()
                        }
                    } label: {
                        VStack(spacing: 16) {
                            Image(systemName: action.icon)
                                .font(.system(size: 26, weight: .light))
                                .foregroundStyle(action.color)
                                .frame(width: 52, height: 52)
                                .background(action.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                            Text(action.label)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color(.separator), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
