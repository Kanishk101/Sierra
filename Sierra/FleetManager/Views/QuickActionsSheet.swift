import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

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
        QuickAction(icon: "wrench.and.screwdriver.fill", label: "Create Maintenance Request", color: accentOrange, tag: "maintenance"),
        QuickAction(icon: "person.badge.plus", label: "Add Staff Member", color: .purple, tag: "staff"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Drag indicator
            Capsule()
                .fill(.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("Quick Actions")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(navyDark)
                .padding(.top, 4)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(actions) { action in
                    Button {
                        switch action.tag {
                        case "staff":    showCreateStaff = true
                        case "vehicle":  showAddVehicle = true
                        case "delivery": showCreateTrip = true
                        default:         dismiss()
                        }
                    } label: {
                        VStack(spacing: 14) {
                            Image(systemName: action.icon)
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(action.color)
                                .frame(width: 56, height: 56)
                                .background(action.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                            Text(action.label)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(navyDark)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color(hex: "F2F3F7").ignoresSafeArea())
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
