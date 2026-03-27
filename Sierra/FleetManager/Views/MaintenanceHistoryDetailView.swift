import SwiftUI

/// Read-only detail view for a completed maintenance record.
struct MaintenanceHistoryDetailView: View {

    let record: MaintenanceRecord

    @Environment(AppDataStore.self) private var store

    private var vehicle: Vehicle? { store.vehicle(for: record.vehicleId) }
    private var performer: StaffMember? { store.staffMember(for: record.performedById) }
    private var parts: [PartUsed] { store.partsUsed(forWorkOrder: record.workOrderId) }

    var body: some View {
        List {
            // MARK: Header
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle?.name ?? "Unknown Vehicle")
                            .font(.headline)
                        if let plate = vehicle?.licensePlate {
                            Text(plate)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    recordStatusBadge(record.status)
                }

                LabeledContent("Service Date") {
                    Text(record.serviceDate.formatted(.dateTime.month(.abbreviated).day().year()))
                }
                LabeledContent("Odometer") {
                    Text("\(record.odometerAtService, specifier: "%.0f") km")
                }
                if let next = record.nextServiceDue {
                    LabeledContent("Next Service Due") {
                        Text(next.formatted(.dateTime.month(.abbreviated).day().year()))
                    }
                }
                LabeledContent("Performed By") {
                    Text(performer?.name ?? "Unknown")
                }
            }

            // MARK: Issue & Repair
            Section("Issue Reported") {
                Text(record.issueReported)
                    .font(.body)
            }

            Section("Repair Details") {
                Text(record.repairDetails)
                    .font(.body)
            }

            // MARK: Costs
            Section("Costs") {
                LabeledContent("Labour") {
                    Text("₹\(record.labourCost, specifier: "%.0f")")
                }
                LabeledContent("Parts") {
                    Text("₹\(record.partsCost, specifier: "%.0f")")
                }
                LabeledContent("Total") {
                    Text("₹\(record.totalCost, specifier: "%.0f")")
                        .fontWeight(.semibold)
                }
            }

            // MARK: Parts Used
            if !parts.isEmpty {
                Section("Parts Used") {
                    ForEach(parts) { part in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(part.partName)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text("₹\(part.totalCost, specifier: "%.0f")")
                                    .font(.subheadline.monospacedDigit())
                            }
                            HStack(spacing: 12) {
                                Text("Qty: \(part.quantity)")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("@ ₹\(part.unitCost, specifier: "%.0f")")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let number = part.partNumber {
                                    Text("#\(number)")
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                                if let supplier = part.supplier {
                                    Text(supplier)
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Service Record")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Status Badge

    private func recordStatusBadge(_ s: MaintenanceRecordStatus) -> some View {
        let color: Color = switch s {
        case .scheduled:  .blue
        case .inProgress: .orange
        case .completed:  .green
        case .cancelled:  .gray
        }
        return Text(s.rawValue)
            .font(SierraFont.scaled(10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}
