import SwiftUI

struct InventoryAdminView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showCreate = false
    @State private var editingPart: InventoryPart?
    @State private var deletingPart: InventoryPart?
    @State private var stockFilter: StockFilter = .all

    private enum StockFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case lowStock = "Low Stock"
        case onOrder = "On Order"
        case overdueDelivery = "Overdue Delivery"
        case inactive = "Inactive"
        var id: String { rawValue }
    }

    private var filtered: [InventoryPart] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = store.inventoryParts
            .filter(matchesStockFilter)
            .sorted { $0.partName.localizedCaseInsensitiveCompare($1.partName) == .orderedAscending }
        guard !q.isEmpty else { return parts }
        return parts.filter {
            $0.partName.lowercased().contains(q)
            || ($0.partNumber ?? "").lowercased().contains(q)
            || ($0.supplier ?? "").lowercased().contains(q)
            || ($0.category ?? "").lowercased().contains(q)
        }
    }

    private var lowStockCount: Int {
        store.inventoryParts.filter { $0.currentQuantity <= $0.reorderLevel && $0.isActive }.count
    }

    private var onOrderCount: Int {
        store.inventoryParts.filter { $0.onOrderQuantity > 0 && $0.isActive }.count
    }

    private var overdueDeliveryCount: Int {
        let now = Date()
        return store.inventoryParts.filter {
            $0.isActive && $0.onOrderQuantity > 0 && ($0.expectedArrivalAt ?? .distantFuture) < now
        }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                summaryRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                filterChips
                    .padding(.bottom, 8)

                if filtered.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filtered) { part in
                                Button {
                                    editingPart = part
                                } label: {
                                    partRowCard(part)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deletingPart = part
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color.appSurface.ignoresSafeArea())
            .navigationTitle("Parts Inventory")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                if store.inventoryParts.isEmpty {
                    await store.loadAll()
                }
            }
            .refreshable {
                await store.loadAll()
            }
            .sheet(isPresented: $showCreate) {
                InventoryPartEditorSheet(part: nil)
                    .environment(store)
            }
            .sheet(item: $editingPart) { part in
                InventoryPartEditorSheet(part: part)
                    .environment(store)
            }
            .alert("Delete Part?", isPresented: .constant(deletingPart != nil), presenting: deletingPart) { part in
                Button("Delete", role: .destructive) {
                    Task {
                        try? await store.deleteInventoryPart(id: part.id)
                        deletingPart = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    deletingPart = nil
                }
            } message: { part in
                Text("This removes \(part.partName) from inventory catalog.")
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.appTextSecondary)
            TextField("Search parts", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 14, weight: .medium, design: .rounded))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.appCardBg))
        .overlay(Capsule().stroke(Color.appDivider.opacity(0.45), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            quickMetricChip(title: "Low Stock", value: lowStockCount, tint: .red)
            quickMetricChip(title: "On Order", value: onOrderCount, tint: .blue)
            quickMetricChip(title: "Overdue", value: overdueDeliveryCount, tint: .orange)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StockFilter.allCases) { filter in
                    Button {
                        stockFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(stockFilter == filter ? Color.appOrange : Color.appTextSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(stockFilter == filter ? Color.appOrange.opacity(0.13) : Color.appCardBg)
                            )
                            .overlay(
                                Capsule().stroke(
                                    stockFilter == filter ? Color.appOrange.opacity(0.35) : Color.appDivider.opacity(0.45),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func quickMetricChip(title: String, value: Int, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func partRowCard(_ part: InventoryPart) -> some View {
        let lowStock = part.currentQuantity <= part.reorderLevel
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(part.partName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)
                    Text((part.partNumber?.isEmpty == false ? part.partNumber! : "No part number") + " · " + (part.supplier ?? "No supplier"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(lowStock ? "Low Stock" : "In Stock")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(lowStock ? Color.red : Color.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background((lowStock ? Color.red : Color.green).opacity(0.12), in: Capsule())
            }

            HStack(spacing: 14) {
                metricText("Current", value: part.currentQuantity, tint: lowStock ? .red : .green)
                metricText("Reorder", value: part.reorderLevel, tint: .orange)
                metricText("On Order", value: part.onOrderQuantity, tint: .blue)
            }

            if let eta = part.expectedArrivalAt, part.onOrderQuantity > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("ETA \(eta.formatted(.dateTime.day().month(.abbreviated).hour().minute()))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.blue.opacity(0.9))
            }

            if !part.isActive {
                Text("Inactive Part")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.appDivider.opacity(0.7), in: Capsule())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.appDivider.opacity(0.45), lineWidth: 1)
        )
    }

    private func metricText(_ label: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer(minLength: 60)
            Image(systemName: "shippingbox")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.35))
            Text("No Parts Found")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
                .padding(.top, 6)
            Text("Try a different filter or add a new part.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
        }
        .padding(.horizontal, 36)
    }

    private func matchesStockFilter(_ part: InventoryPart) -> Bool {
        switch stockFilter {
        case .all:
            return true
        case .lowStock:
            return part.isActive && part.currentQuantity <= part.reorderLevel
        case .onOrder:
            return part.isActive && part.onOrderQuantity > 0
        case .overdueDelivery:
            return part.isActive && part.onOrderQuantity > 0 && (part.expectedArrivalAt ?? .distantFuture) < Date()
        case .inactive:
            return !part.isActive
        }
    }
}

private struct InventoryPartEditorSheet: View {
    let part: InventoryPart?
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var number = ""
    @State private var supplier = ""
    @State private var category = ""
    @State private var unit = "pcs"
    @State private var currentQty = "0"
    @State private var reorderLevel = "0"
    @State private var onOrderQty = "0"
    @State private var hasEta = false
    @State private var expectedArrival = Date()
    @State private var isActive = true
    @State private var selectedVehicleIds = Set<UUID>()

    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Part") {
                    TextField("Part name", text: $name)
                    TextField("Part number", text: $number)
                    TextField("Supplier", text: $supplier)
                    TextField("Category", text: $category)
                    TextField("Unit (pcs/ltr/set)", text: $unit)
                }

                Section("Stock") {
                    TextField("Current quantity", text: $currentQty)
                        .keyboardType(.numberPad)
                    TextField("Reorder level", text: $reorderLevel)
                        .keyboardType(.numberPad)
                    TextField("On order quantity", text: $onOrderQty)
                        .keyboardType(.numberPad)
                    Toggle("Has expected arrival", isOn: $hasEta)
                    if hasEta {
                        DatePicker("Expected arrival", selection: $expectedArrival, displayedComponents: [.date, .hourAndMinute])
                    }
                    Toggle("Active", isOn: $isActive)
                }

                Section("Compatible Vehicles") {
                    ForEach(store.vehicles) { vehicle in
                        Button {
                            if selectedVehicleIds.contains(vehicle.id) {
                                selectedVehicleIds.remove(vehicle.id)
                            } else {
                                selectedVehicleIds.insert(vehicle.id)
                            }
                        } label: {
                            HStack {
                                Text("\(vehicle.name) (\(vehicle.licensePlate))")
                                Spacer()
                                if selectedVehicleIds.contains(vehicle.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(part == nil ? "Add Part" : "Edit Part")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func loadExisting() {
        guard let part else { return }
        name = part.partName
        number = part.partNumber ?? ""
        supplier = part.supplier ?? ""
        category = part.category ?? ""
        unit = part.unit
        currentQty = String(part.currentQuantity)
        reorderLevel = String(part.reorderLevel)
        onOrderQty = String(part.onOrderQuantity)
        hasEta = part.expectedArrivalAt != nil
        expectedArrival = part.expectedArrivalAt ?? Date()
        isActive = part.isActive
        selectedVehicleIds = Set(part.compatibleVehicleIds)
    }

    private func save() async {
        errorMessage = nil
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Part name is required."
            return
        }
        guard let current = Int(currentQty), let reorder = Int(reorderLevel), let onOrder = Int(onOrderQty), current >= 0, reorder >= 0, onOrder >= 0 else {
            errorMessage = "Quantities must be valid non-negative numbers."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            if let part {
                try await store.updateInventoryPart(
                    id: part.id,
                    partName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    partNumber: number.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    category: category.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    unit: unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "pcs" : unit,
                    currentQuantity: current,
                    reorderLevel: reorder,
                    onOrderQuantity: onOrder,
                    expectedArrivalAt: hasEta ? expectedArrival : nil,
                    compatibleVehicleIds: Array(selectedVehicleIds),
                    isActive: isActive
                )
            } else {
                try await store.createInventoryPart(
                    partName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    partNumber: number.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    category: category.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    unit: unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "pcs" : unit,
                    currentQuantity: current,
                    reorderLevel: reorder,
                    onOrderQuantity: onOrder,
                    expectedArrivalAt: hasEta ? expectedArrival : nil,
                    compatibleVehicleIds: Array(selectedVehicleIds),
                    isActive: isActive
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
