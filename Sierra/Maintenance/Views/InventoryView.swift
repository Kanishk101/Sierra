import SwiftUI

/// Inventory tab — searchable part catalog derived from backend-maintained data.
/// Sources:
/// - spare_parts_requests (demand, approvals, allocations, on-order, ETA)
/// - parts_used (consumption)
/// - maintenance_tasks/work_orders/vehicles (compatibility context)
struct InventoryView: View {
    @Environment(AppDataStore.self) private var store
    @State private var showVINScanner = false
    @State private var scanResult: InventoryScanResult?
    @State private var searchText = ""
    @State private var selectedPart: PartInventorySnapshot?
    @State private var identifierCursorByPartKey: [String: Int] = [:]
    @State private var categoryFilter: InventoryCategoryFilter = .all

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    enum InventoryCategoryFilter: String, CaseIterable {
        case all = "All"
        case lowStock = "Low Stock"
        case onOrder = "On Order"
    }

    struct PartInventorySnapshot: Identifiable {
        var id: String { key }
        let key: String
        let name: String
        let partNumber: String?
        let supplier: String?

        let requestedQty: Int
        let allocatedQty: Int
        let usedQty: Int
        let onOrderQty: Int
        let availableSnapshot: Int

        let pendingApprovals: Int
        let pendingDeliveryCount: Int
        let expectedArrival: Date?

        let compatibleVehicleIds: [UUID]
    }

    private var tasksById: [UUID: MaintenanceTask] {
        Dictionary(uniqueKeysWithValues: store.maintenanceTasks.map { ($0.id, $0) })
    }

    private var workOrdersById: [UUID: WorkOrder] {
        Dictionary(uniqueKeysWithValues: store.workOrders.map { ($0.id, $0) })
    }

    private var snapshots: [PartInventorySnapshot] {
        var buckets: [String: (requests: [SparePartsRequest], used: [PartUsed], base: InventoryPart?)] = [:]

        for part in store.inventoryParts where part.isActive {
            let key = normalizedKey(name: part.partName, partNumber: part.partNumber)
            buckets[key] = (requests: [], used: [], base: part)
        }

        for request in store.sparePartsRequests {
            let key = normalizedKey(name: request.partName, partNumber: request.partNumber)
            var bucket = buckets[key] ?? ([], [], nil)
            bucket.requests.append(request)
            buckets[key] = bucket
        }

        for used in store.partsUsed {
            let key = normalizedKey(name: used.partName, partNumber: used.partNumber)
            var bucket = buckets[key] ?? ([], [], nil)
            bucket.used.append(used)
            buckets[key] = bucket
        }

        return buckets.compactMap { key, bucket in
            let requests = bucket.requests
            let used = bucket.used
            let base = bucket.base
            guard !requests.isEmpty || !used.isEmpty || base != nil else { return nil }

            let sampleReq = requests.max(by: { $0.updatedAt < $1.updatedAt })
            let sampleUsed = used.max(by: { $0.createdAt < $1.createdAt })

            let partName = base?.partName ?? sampleReq?.partName ?? sampleUsed?.partName ?? "Unnamed Part"
            let partNumber = base?.partNumber ?? sampleReq?.partNumber ?? sampleUsed?.partNumber
            let supplier = base?.supplier ?? sampleReq?.supplier ?? sampleUsed?.supplier

            let requestedQty = requests.reduce(0) { $0 + max(0, $1.quantity) }
            let allocatedQty = requests.reduce(0) { $0 + max(0, $1.quantityAllocated) }
            let usedQty = used.reduce(0) { $0 + max(0, $1.quantity) }
            let onOrderQty = max(
                base?.onOrderQuantity ?? 0,
                requests.reduce(0) { $0 + max(0, $1.quantityOnOrder) }
            )
            let availableSnapshot = base?.currentQuantity ?? (requests.map(\.quantityAvailable).max() ?? 0)

            let pendingApprovals = requests.filter { $0.status == .pending }.count
            let pendingDeliveryCount = requests.filter {
                $0.status == .approved && (($0.quantityOnOrder > 0) || ($0.quantityAllocated < $0.quantity))
            }.count

            let expectedArrival = base?.expectedArrivalAt ?? requests.compactMap(\.expectedArrivalAt).min()

            var vehicleIds = Set(base?.compatibleVehicleIds ?? [])
            for req in requests {
                if let task = tasksById[req.maintenanceTaskId] {
                    vehicleIds.insert(task.vehicleId)
                }
            }
            for part in used {
                if let wo = workOrdersById[part.workOrderId] {
                    vehicleIds.insert(wo.vehicleId)
                }
            }

            return PartInventorySnapshot(
                key: key,
                name: partName,
                partNumber: partNumber,
                supplier: supplier,
                requestedQty: requestedQty,
                allocatedQty: allocatedQty,
                usedQty: usedQty,
                onOrderQty: onOrderQty,
                availableSnapshot: availableSnapshot,
                pendingApprovals: pendingApprovals,
                pendingDeliveryCount: pendingDeliveryCount,
                expectedArrival: expectedArrival,
                compatibleVehicleIds: Array(vehicleIds)
            )
        }
        .sorted { lhs, rhs in
            // Priority: pending deliveries, then pending approvals, then name
            let lHot = (lhs.pendingDeliveryCount + lhs.pendingApprovals) > 0
            let rHot = (rhs.pendingDeliveryCount + rhs.pendingApprovals) > 0
            if lHot != rHot { return lHot }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var categorySnapshots: [PartInventorySnapshot] {
        snapshots.filter { part in
            let inStock = max(0, part.availableSnapshot - part.allocatedQty - part.usedQty)
            switch categoryFilter {
            case .all:
                return true
            case .lowStock:
                return inStock <= 2
            case .onOrder:
                return part.onOrderQty > 0 || part.pendingDeliveryCount > 0
            }
        }
    }

    private var filteredSnapshots: [PartInventorySnapshot] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return categorySnapshots }

        return categorySnapshots.filter { part in
            let vehiclesBlob = compatibleVehicleSearchBlob(for: part)
            let blob = [
                part.name.lowercased(),
                (part.partNumber ?? "").lowercased(),
                (part.supplier ?? "").lowercased(),
                vehiclesBlob
            ].joined(separator: " ")
            return blob.contains(q)
        }
    }

    private var totalPartsCount: Int { categorySnapshots.count }
    private var lowStockCount: Int {
        categorySnapshots.filter { max(0, $0.availableSnapshot - $0.allocatedQty - $0.usedQty) <= 2 }.count
    }
    private var onOrderCount: Int { categorySnapshots.filter { $0.onOrderQty > 0 || $0.pendingDeliveryCount > 0 }.count }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 20)
                .padding(.top, 8)

            categoryChips
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)

            summaryRow
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 14) {
                    if filteredSnapshots.isEmpty {
                        emptyState
                            .padding(.top, 20)
                    } else {
                        ForEach(filteredSnapshots) { part in
                            inventoryCard(part)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable {
                await store.loadMaintenanceData(staffId: currentUserId)
            }
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showVINScanner = true } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(SierraFont.scaled(17, weight: .semibold))
                        .foregroundStyle(Color.appOrange)
                }
            }
        }
        .sheet(isPresented: $showVINScanner) {
            NavigationStack {
                VINScannerView(scanResult: $scanResult)
            }
        }
        .sheet(item: $selectedPart) { part in
            NavigationStack {
                InventoryPartDetailSheet(part: part)
                    .environment(store)
            }
        }
        .onChange(of: scanResult) { _, result in
            guard let result else { return }
            handleScanResult(result)
        }
        .task {
            await store.loadMaintenanceData(staffId: currentUserId)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.appTextSecondary)
            TextField("Search part name, number, supplier, vehicle", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(SierraFont.scaled(14, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Capsule().fill(Color.appCardBg))
        .overlay(Capsule().stroke(Color.appDivider.opacity(0.45), lineWidth: 1))
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryBox(value: totalPartsCount, label: "Catalog", icon: "shippingbox.fill", tint: .appOrange)
            summaryBox(value: lowStockCount, label: "Low Stock", icon: "exclamationmark.triangle.fill", tint: .red)
            summaryBox(value: onOrderCount, label: "On Order", icon: "clock.badge.fill", tint: .blue)
        }
    }

    private var categoryChips: some View {
        HStack(spacing: 8) {
            ForEach(InventoryCategoryFilter.allCases, id: \.self) { filter in
                Button {
                    categoryFilter = filter
                } label: {
                    Text(filter.rawValue)
                        .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                        .foregroundStyle(categoryFilter == filter ? Color.appOrange : Color.appTextPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(
                                categoryFilter == filter ? Color.appOrange.opacity(0.10) : Color.appCardBg
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                categoryFilter == filter ? Color.appOrange.opacity(0.3) : Color.appDivider.opacity(0.4),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryBox(value: Int, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(SierraFont.scaled(10, weight: .semibold))
                Text("\(value)")
                    .font(SierraFont.scaled(21, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint)
            Text(label)
                .font(SierraFont.scaled(11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.18), lineWidth: 1))
    }

    private func inventoryCard(_ part: PartInventorySnapshot) -> some View {
        let inStock = max(0, part.availableSnapshot - part.allocatedQty)
        let isLowStock = inStock <= 2
        let stockTint: Color = isLowStock ? .red : .green
        let vehicleNames = compatibleVehicleNames(for: part)
        let hasPendingState = part.pendingApprovals > 0 || part.pendingDeliveryCount > 0

        return VStack(alignment: .leading, spacing: 12) {
            inventoryCardHeader(part: part, isLowStock: isLowStock, stockTint: stockTint)

            HStack(spacing: 14) {
                metricLine(value: inStock, label: "Current", tint: isLowStock ? .red : .green, icon: "shippingbox.fill")
                metricLine(value: part.onOrderQty, label: "On Order", tint: .blue, icon: "clock.badge.fill")
                metricLine(value: part.pendingApprovals, label: "Pending", tint: .orange, icon: "clock.fill")
            }

            if !vehicleNames.isEmpty {
                compatibleVehiclesSection(vehicleNames)
            }

            if hasPendingState {
                pendingInventoryState(part: part)
            }

            Text("Read-only for maintenance personnel")
                .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.appDivider.opacity(0.3)))
        }
        .onTapGesture {
            selectedPart = part
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(part.name), \(inStock) in stock")
        .accessibilityHint("Opens part details")
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.appDivider.opacity(0.4), lineWidth: 1)
        )
    }

    private func inventoryCardHeader(
        part: PartInventorySnapshot,
        isLowStock: Bool,
        stockTint: Color
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(part.name)
                    .font(SierraFont.scaled(16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)

                if let identifierText = currentIdentifierText(for: part) {
                    Button {
                        cycleIdentifier(for: part)
                    } label: {
                        HStack(spacing: 6) {
                            Text(identifierText)
                                .font(SierraFont.scaled(11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.appTextSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            if identifierVariants(for: part).count > 1 {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(SierraFont.scaled(10, weight: .semibold))
                                    .foregroundStyle(Color.appOrange.opacity(0.9))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cycle part identifier")
                }

                if let supplier = part.supplier, !supplier.isEmpty {
                    Text("Supplier: \(supplier)")
                        .font(SierraFont.scaled(12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Circle().fill(stockTint).frame(width: 8, height: 8)
                Text(isLowStock ? "Low Stock" : "In Stock")
                    .font(SierraFont.scaled(10, weight: .bold, design: .rounded))
                    .foregroundStyle(stockTint)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(stockTint.opacity(0.12), in: Capsule())
        }
    }

    private func compatibleVehiclesSection(_ vehicleNames: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Compatible Vehicles")
                .font(SierraFont.scaled(11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
            FlexibleTags(values: vehicleNames)
        }
    }

    private func pendingInventoryState(part: PartInventorySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if part.pendingApprovals > 0 {
                    Label("\(part.pendingApprovals) pending approval", systemImage: "clock.fill")
                        .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.orange)
                }
                if part.pendingDeliveryCount > 0 {
                    Label("\(part.pendingDeliveryCount) awaiting delivery", systemImage: "shippingbox.fill")
                        .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.blue)
                }
                Spacer()
            }

            if let eta = part.expectedArrival {
                Text("Expected by \(eta.formatted(.dateTime.day().month(.abbreviated).hour().minute()))")
                    .font(SierraFont.scaled(11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    private func metricLine(value: Int, label: String, tint: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(SierraFont.scaled(10, weight: .semibold))
            Text("\(max(0, value))")
                .font(SierraFont.scaled(13, weight: .bold, design: .rounded))
            Text(label)
                .font(SierraFont.scaled(11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(SierraFont.scaled(48, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.3))
            Text("No Parts")
                .font(SierraFont.scaled(20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            Text("Parts catalog for your assigned maintenance tasks\nwill appear here.")
                .font(SierraFont.scaled(14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func normalizedKey(name: String, partNumber: String?) -> String {
        let num = (partNumber ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let nm = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return num.isEmpty ? nm : "\(num)|\(nm)"
    }

    private func compatibleVehicleNames(for part: PartInventorySnapshot) -> [String] {
        part.compatibleVehicleIds.compactMap { id in
            guard let v = store.vehicle(for: id) else { return nil }
            return "\(v.name) (\(v.licensePlate))"
        }
        .sorted()
    }

    private func compatibleVehicleSearchBlob(for part: PartInventorySnapshot) -> String {
        part.compatibleVehicleIds.compactMap { id -> String? in
            guard let v = store.vehicle(for: id) else { return nil }
            return "\(v.name) \(v.licensePlate) \(v.vin)"
        }
        .joined(separator: " ")
        .lowercased()
    }

    private func handleScanResult(_ result: InventoryScanResult) {
        let matches = matchParts(for: result)
        if matches.count == 1, let first = matches.first {
            selectedPart = first
            return
        }

        // Multiple hits: narrow the list using the best token.
        let tokens = lookupTokens(from: result)
        if let token = tokens.first(where: { !$0.isEmpty }) {
            searchText = token
        } else {
            searchText = result.normalizedValue
        }
    }

    private func matchParts(for result: InventoryScanResult) -> [PartInventorySnapshot] {
        let tokens = lookupTokens(from: result)
        guard !tokens.isEmpty else { return [] }

        switch result.kind {
        case .vin:
            let normalizedVIN = normalizeIdentifier(result.normalizedValue)
            let matchedVehicles = store.vehicles.filter {
                normalizeIdentifier($0.vin) == normalizedVIN
                    || normalizeIdentifier($0.vin).contains(normalizedVIN)
            }
            let vehicleIds = Set(matchedVehicles.map(\.id))
            if !vehicleIds.isEmpty {
                return snapshots.filter { !$0.compatibleVehicleIds.filter(vehicleIds.contains).isEmpty }
            }
            // Fallback: attempt token-based part match.
            return snapshots.filter { snapshot in
                tokens.contains { snapshotMatches(snapshot, token: $0) }
            }

        case .barcode, .qr, .partNumber, .unknown:
            return snapshots.filter { snapshot in
                tokens.contains { snapshotMatches(snapshot, token: $0) }
            }
        }
    }

    private func lookupTokens(from result: InventoryScanResult) -> [String] {
        var tokens: [String] = []
        let base = normalizeIdentifier(result.normalizedValue)
        if !base.isEmpty { tokens.append(base) }

        if result.kind == .qr || result.kind == .barcode {
            let raw = result.rawValue
            if let url = URL(string: raw), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                for item in components.queryItems ?? [] {
                    let key = item.name.lowercased()
                    guard ["part", "part_id", "partnumber", "pn", "vin", "sku", "code"].contains(key),
                          let value = item.value else { continue }
                    let normalized = normalizeIdentifier(value)
                    if !normalized.isEmpty { tokens.append(normalized) }
                }
                let pathTokens = components.path.split(separator: "/").map(String.init).map(normalizeIdentifier)
                tokens.append(contentsOf: pathTokens.filter { !$0.isEmpty })
            }
        }

        return tokens.reduce(into: [String]()) { acc, token in
            if !acc.contains(token) { acc.append(token) }
        }
    }

    private func snapshotMatches(_ snapshot: PartInventorySnapshot, token: String) -> Bool {
        let normalizedToken = normalizeIdentifier(token)
        guard !normalizedToken.isEmpty else { return false }

        let normalizedPartNo = normalizeIdentifier(snapshot.partNumber ?? "")
        if !normalizedPartNo.isEmpty &&
            (normalizedPartNo == normalizedToken || normalizedPartNo.contains(normalizedToken) || normalizedToken.contains(normalizedPartNo)) {
            return true
        }

        let name = normalizeIdentifier(snapshot.name)
        if name.contains(normalizedToken) { return true }

        let supplier = normalizeIdentifier(snapshot.supplier ?? "")
        if !supplier.isEmpty && supplier.contains(normalizedToken) { return true }

        for vehicleId in snapshot.compatibleVehicleIds {
            guard let vehicle = store.vehicle(for: vehicleId) else { continue }
            if normalizeIdentifier(vehicle.vin).contains(normalizedToken)
                || normalizeIdentifier(vehicle.licensePlate).contains(normalizedToken) {
                return true
            }
        }
        return false
    }

    private func normalizeIdentifier(_ value: String) -> String {
        value
            .uppercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private func identifierVariants(for part: PartInventorySnapshot) -> [String] {
        var identifiers: [String] = []

        if let pn = part.partNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !pn.isEmpty {
            identifiers.append("Part ID: \(pn.uppercased())")
        }

        let vehicles = part.compatibleVehicleIds.compactMap(store.vehicle(for:))
        for vehicle in vehicles.prefix(2) {
            if !vehicle.vin.isEmpty {
                identifiers.append("VIN: \(vehicle.vin.uppercased())")
            }
            if !vehicle.licensePlate.isEmpty {
                identifiers.append("Plate: \(vehicle.licensePlate.uppercased())")
            }
        }

        let unique = identifiers.reduce(into: [String]()) { acc, id in
            if !acc.contains(id) { acc.append(id) }
        }
        return unique
    }

    private func currentIdentifierText(for part: PartInventorySnapshot) -> String? {
        let variants = identifierVariants(for: part)
        guard !variants.isEmpty else { return nil }
        let index = identifierCursorByPartKey[part.key, default: 0] % variants.count
        return variants[index]
    }

    private func cycleIdentifier(for part: PartInventorySnapshot) {
        let variants = identifierVariants(for: part)
        guard variants.count > 1 else { return }
        let current = identifierCursorByPartKey[part.key, default: 0]
        identifierCursorByPartKey[part.key] = (current + 1) % variants.count
    }
}

private struct InventoryPartDetailSheet: View {
    let part: InventoryView.PartInventorySnapshot
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var inStock: Int { max(0, part.availableSnapshot - part.allocatedQty - part.usedQty) }
    private var recentRequests: [SparePartsRequest] {
        store.sparePartsRequests
            .filter {
                let partNoMatch = ($0.partNumber ?? "").caseInsensitiveCompare(part.partNumber ?? "") == .orderedSame
                let nameMatch = $0.partName.caseInsensitiveCompare(part.name) == .orderedSame
                return partNoMatch || nameMatch
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
    private var recentUsage: [PartUsed] {
        store.partsUsed
            .filter {
                let partNoMatch = ($0.partNumber ?? "").caseInsensitiveCompare(part.partNumber ?? "") == .orderedSame
                let nameMatch = $0.partName.caseInsensitiveCompare(part.name) == .orderedSame
                return partNoMatch || nameMatch
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
    private var recentActivity: [PartActivityItem] {
        let requestItems: [PartActivityItem] = recentRequests.map { req in
            let detail = "Qty \(req.quantity) • Alloc \(req.quantityAllocated) • On Order \(req.quantityOnOrder)"
                + (req.workOrderId != nil ? " • Work Order" : "")
            return PartActivityItem(
                title: req.status.rawValue,
                subtitle: detail,
                timestamp: req.reviewedAt ?? req.adminOrderedAt ?? req.createdAt,
                tint: statusTint(req.status)
            )
        }

        let usageItems: [PartActivityItem] = recentUsage.map { used in
            PartActivityItem(
                title: "Consumed in Work Order",
                subtitle: "Qty \(used.quantity)",
                timestamp: used.createdAt,
                tint: .blue
            )
        }

        return (requestItems + usageItems)
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(part.name)
                        .font(SierraFont.scaled(22, weight: .bold, design: .rounded))
                    if let pn = part.partNumber, !pn.isEmpty {
                        Text("Part Code: \(pn)")
                            .font(SierraFont.scaled(12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if let supplier = part.supplier, !supplier.isEmpty {
                        Text("Supplier: \(supplier)")
                            .font(SierraFont.scaled(13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 10) {
                    statLine("Current Quantity", "\(inStock)", tint: inStock <= 2 ? .red : .green)
                    statLine("On Order", "\(part.onOrderQty)", tint: .blue)
                    statLine("Pending Approval", "\(part.pendingApprovals)", tint: .orange)
                    statLine("Awaiting Delivery", "\(part.pendingDeliveryCount)", tint: .purple)
                    if let eta = part.expectedArrival {
                        statLine("Expected Arrival", eta.formatted(.dateTime.day().month(.abbreviated).hour().minute()), tint: .secondary)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.appCardBg))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.5), lineWidth: 1))

                if !part.compatibleVehicleIds.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compatible Vehicles")
                            .font(SierraFont.scaled(13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                        FlexibleTags(values: part.compatibleVehicleIds.compactMap { id in
                            guard let v = store.vehicle(for: id) else { return nil }
                            return "\(v.name) (\(v.licensePlate))"
                        })
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.appCardBg))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.5), lineWidth: 1))
                }

                if !recentActivity.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Activity")
                            .font(SierraFont.scaled(13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                        ForEach(Array(recentActivity.prefix(6))) { item in
                            HStack {
                                Text(item.title)
                                    .font(SierraFont.scaled(11, weight: .bold, design: .rounded))
                                    .foregroundStyle(item.tint)
                                if !item.subtitle.isEmpty {
                                    Text(item.subtitle)
                                        .font(SierraFont.scaled(11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(item.timestamp.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                    .font(SierraFont.scaled(11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.appCardBg))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.5), lineWidth: 1))
                }

            }
            .padding(20)
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Part Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            await store.loadMaintenanceData(staffId: currentUserId)
        }
    }

    private func statLine(_ label: String, _ value: String, tint: Color) -> some View {
        HStack {
            Text(label)
                .font(SierraFont.scaled(13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(SierraFont.scaled(13, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    private func statusTint(_ status: SparePartsRequestStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        case .fulfilled: return .blue
        }
    }

    private struct PartActivityItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let timestamp: Date
        let tint: Color
    }
}

private struct FlexibleTags: View {
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(values.prefix(3).enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(SierraFont.scaled(11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.appDivider.opacity(0.35)))
            }
            if values.count > 3 {
                Text("+\(values.count - 3) more")
                    .font(SierraFont.scaled(11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appOrange)
            }
        }
    }
}
