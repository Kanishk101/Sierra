import SwiftUI

private let navyDark = Color(hex: "0D1B2A")

struct VehicleListView: View {
    @State private var vehicles = Vehicle.samples
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vehicles) { vehicle in
                    vehicleRow(vehicle)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .onDelete(perform: deleteVehicle)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "F2F3F7").ignoresSafeArea())
            .navigationTitle("Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(navyDark)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addVehiclePlaceholder
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Vehicle Row

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        HStack(spacing: 14) {
            // Vehicle icon
            Image(systemName: "car.fill")
                .font(.system(size: 20))
                .foregroundStyle(navyDark.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(navyDark.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(navyDark)
                Text("\(vehicle.model) · \(vehicle.licensePlate)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge(vehicle.status)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
    }

    private func statusBadge(_ status: VehicleStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .active:        ("Active", .green)
        case .inMaintenance: ("Maint.", .orange)
        case .idle:          ("Idle", Color(hex: "8E8E93"))
        }
        return Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Delete

    private func deleteVehicle(at offsets: IndexSet) {
        vehicles.remove(atOffsets: offsets)
    }

    // MARK: - Add Sheet Placeholder

    private var addVehiclePlaceholder: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Image(systemName: "plus.rectangle.on.folder.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(navyDark.opacity(0.5))

            Text("Add Vehicle")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(navyDark)

            Text("Vehicle registration form coming soon.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "F2F3F7"))
    }
}

#Preview {
    VehicleListView()
}
