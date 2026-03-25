import SwiftUI

// MARK: - SparePartsRequestSheet
// Matches the reference PartsRequestSheet:
// header banner → inventory requirements section → additional parts section → bottom submit bar

struct SparePartsRequestSheet: View {

    let task: MaintenanceTask

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var primaryParts: [DraftPart] = []
    @State private var extraParts: [DraftPart] = []
    @State private var isSubmitting = false

    private let catalog = PartsCatalog.items
    private var personnelId: UUID? { AuthManager.shared.currentUser?.id }

    private var allParts: [DraftPart] {
        primaryParts.filter { !$0.name.isEmpty } + extraParts.filter { !$0.name.isEmpty }
    }

    init(task: MaintenanceTask) {
        self.task = task
        // Seed one blank row if nothing is pre-populated
        _primaryParts = State(initialValue: [DraftPart()])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                VStack(spacing: 0) {
                    headerBanner
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            inventorySection
                            additionalSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                    bottomBar
                }
            }
            .navigationTitle("Request Parts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appOrange)
                }
            }
        }
    }

    // MARK: - Header Banner

    private var headerBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.title3).foregroundStyle(Color.appOrange)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                Text("Review and request the parts you need for this repair.")
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.appOrange.opacity(0.07))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.appOrange.opacity(0.15)), alignment: .bottom)
    }

    // MARK: - Inventory Requirements Section (primary parts)

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Parts Required", subtitle: "Add the parts needed for this repair")
            VStack(spacing: 0) {
                ForEach($primaryParts) { $part in
                    PartInputRow(part: $part, catalog: catalog) {
                        primaryParts.removeAll { $0.id == part.id }
                    }
                    if part.id != primaryParts.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
                addRowButton(label: "Add Part") {
                    primaryParts.append(DraftPart())
                }
            }
            .background(Color.appCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }

    // MARK: - Additional Parts Section

    private var additionalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Additional Parts", subtitle: "Any extra parts not listed above")
            VStack(spacing: 0) {
                if extraParts.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.square.dashed").font(.title3)
                            .foregroundStyle(Color.appTextSecondary.opacity(0.45))
                        Text("No additional parts added yet")
                            .font(.subheadline).foregroundStyle(Color.appTextSecondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 18)
                } else {
                    ForEach($extraParts) { $part in
                        PartInputRow(part: $part, catalog: catalog) {
                            extraParts.removeAll { $0.id == part.id }
                        }
                        if part.id != extraParts.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                addRowButton(label: "Add Another Part") {
                    extraParts.append(DraftPart())
                }
            }
            .background(Color.appCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .padding(.top, 16)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        let count = allParts.count
        return Button {
            Task { await submitParts() }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting { ProgressView().tint(.white).scaleEffect(0.85) }
                Image(systemName: "paperplane.fill")
                Text(count == 0 ? "Submit to Admin" : "Submit \(count) Item\(count == 1 ? "" : "s") to Admin")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                count == 0 ? Color.appTextSecondary.opacity(0.35) : Color.appOrange,
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .disabled(isSubmitting || count == 0)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.appCardBg.shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -2))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption.weight(.bold)).foregroundStyle(Color.appTextSecondary).kerning(0.8)
            Text(subtitle)
                .font(.caption).foregroundStyle(Color.appTextSecondary.opacity(0.8))
        }
        .padding(.top, 14).padding(.bottom, 8)
    }

    private func addRowButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill").foregroundStyle(Color.appOrange)
                Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Color.appOrange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(Color.appOrange.opacity(0.05))
        }
    }

    // MARK: - Submit

    private func submitParts() async {
        guard let pid = personnelId, !allParts.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let workOrderId = store.workOrder(forMaintenanceTask: task.id)?.id
        do {
            for part in allParts {
                try await SparePartsRequestService.submitRequest(
                    maintenanceTaskId: task.id,
                    workOrderId: workOrderId,
                    requestedById: pid,
                    partName: part.name,
                    partNumber: part.partNumber.isEmpty ? nil : part.partNumber,
                    quantity: part.quantity,
                    estimatedUnitCost: nil,
                    supplier: nil,
                    reason: part.reason
                )
            }
            await store.loadMaintenanceData(staffId: pid)
            dismiss()
        } catch {
            // Keep sheet open on error; could surface via alert here
            print("[SparePartsRequestSheet] Submit error: \(error.localizedDescription)")
        }
    }
}

// MARK: - DraftPart (local draft model)

struct DraftPart: Identifiable {
    let id = UUID()
    var name: String = ""
    var partNumber: String = ""
    var quantity: Int = 1
    var reason: String = ""
    var useDropdown: Bool = true
}

// MARK: - PartInputRow

struct PartInputRow: View {
    @Binding var part: DraftPart
    let catalog: [String]
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Part name: catalog dropdown or free-type
            HStack(spacing: 8) {
                partNameField
                Button {
                    part.useDropdown.toggle()
                    if part.useDropdown { part.name = "" }
                } label: {
                    Image(systemName: part.useDropdown ? "pencil.circle" : "list.bullet.circle")
                        .font(.title3).foregroundStyle(Color.appOrange)
                }
                .buttonStyle(.plain)
            }

            // Part number + quantity
            HStack(spacing: 8) {
                Image(systemName: "barcode").font(.caption).foregroundStyle(Color.appTextSecondary)
                TextField("Part no.", text: $part.partNumber)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(maxWidth: 110)
                Divider().frame(height: 18)
                Stepper("Qty: \(part.quantity)", value: $part.quantity, in: 1...99)
                    .font(.caption.weight(.medium)).foregroundStyle(Color.appTextPrimary)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.appDivider, lineWidth: 0.8))

            // Reason
            HStack(spacing: 6) {
                Image(systemName: "text.bubble").font(.caption).foregroundStyle(Color.appTextSecondary)
                TextField("Reason for request (optional)", text: $part.reason)
                    .font(.caption).foregroundStyle(Color.appTextPrimary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.appDivider, lineWidth: 0.8))

            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash").font(.caption).foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    @ViewBuilder
    private var partNameField: some View {
        if part.useDropdown {
            Menu {
                ForEach(catalog, id: \.self) { item in
                    Button(item) { part.name = item }
                }
                Divider()
                Button { part.useDropdown = false; part.name = "" } label: {
                    Label("Type manually…", systemImage: "pencil")
                }
            } label: {
                HStack {
                    Text(part.name.isEmpty ? "Select part from catalog…" : part.name)
                        .font(.subheadline)
                        .foregroundStyle(part.name.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(Color.appTextSecondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(
                    part.name.isEmpty ? Color.appDivider : Color.appOrange.opacity(0.5), lineWidth: 1))
            }
        } else {
            TextField("Type part name…", text: $part.name)
                .font(.subheadline).foregroundStyle(Color.appTextPrimary)
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.appOrange.opacity(0.5), lineWidth: 1))
        }
    }
}

// MARK: - Parts Catalog

enum PartsCatalog {
    static let items: [String] = [
        "Engine Oil Filter",
        "Air Filter",
        "Fuel Filter",
        "Brake Pad (Front)",
        "Brake Pad (Rear)",
        "Brake Disc (Front)",
        "Brake Disc (Rear)",
        "Spark Plug",
        "Ignition Coil",
        "Alternator Belt",
        "Timing Belt",
        "Coolant / Antifreeze",
        "Radiator Hose",
        "Thermostat",
        "Water Pump",
        "Power Steering Fluid",
        "Transmission Fluid",
        "Differential Oil",
        "Shock Absorber (Front)",
        "Shock Absorber (Rear)",
        "CV Joint/Boot",
        "Tie Rod End",
        "Ball Joint",
        "Wheel Bearing",
        "Tyre (Front)",
        "Tyre (Rear)",
        "Battery",
        "Starter Motor",
        "Wiper Blade (Front)",
        "Wiper Blade (Rear)",
        "Headlight Bulb",
        "Tail Light Bulb",
        "Cabin Air Filter",
        "EGR Valve",
        "Oxygen Sensor",
        "ABS Sensor",
        "Clutch Plate",
        "Pressure Plate",
        "Flywheel",
        "Exhaust Gasket",
    ]
}
