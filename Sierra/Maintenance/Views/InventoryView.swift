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
    @State private var partDetailMode: InventoryPartDetailSheet.ActionMode = .request

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

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

    private var filteredSnapshots: [PartInventorySnapshot] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return snapshots }

        return snapshots.filter { part in
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

    private var totalPartsCount: Int { snapshots.count }
    private var lowStockCount: Int {
        snapshots.filter { max(0, $0.availableSnapshot - $0.allocatedQty - $0.usedQty) <= 2 }.count
    }
    private var onOrderCount: Int { snapshots.filter { $0.onOrderQty > 0 || $0.pendingDeliveryCount > 0 }.count }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                searchBar
                summaryRow

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
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showVINScanner = true } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 17, weight: .semibold))
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
                InventoryPartDetailSheet(part: part, initialMode: partDetailMode)
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
        .refreshable {
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
                .font(.system(size: 14, weight: .medium, design: .rounded))
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

    private func summaryBox(value: Int, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text("\(value)")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.18), lineWidth: 1))
    }

    private func inventoryCard(_ part: PartInventorySnapshot) -> some View {
        let inStock = max(0, part.availableSnapshot - part.allocatedQty - part.usedQty)
        let isLowStock = inStock <= 2

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(part.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)

                    if let identifierText = currentIdentifierText(for: part) {
                        Button {
                            cycleIdentifier(for: part)
                        } label: {
                            HStack(spacing: 6) {
                                Text(identifierText)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.appTextSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                if identifierVariants(for: part).count > 1 {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color.appOrange.opacity(0.9))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if let supplier = part.supplier, !supplier.isEmpty {
                        Text("Supplier: \(supplier)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle().fill(isLowStock ? Color.red : Color.green).frame(width: 8, height: 8)
                    Text(isLowStock ? "Low Stock" : "In Stock")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(isLowStock ? Color.red : Color.green)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background((isLowStock ? Color.red : Color.green).opacity(0.12), in: Capsule())
            }

            HStack(spacing: 14) {
                metricLine(value: inStock, label: "Current", tint: isLowStock ? .red : .green, icon: "shippingbox.fill")
                metricLine(value: part.usedQty, label: "Used", tint: .orange, icon: "wrench.and.screwdriver.fill")
                metricLine(value: part.onOrderQty, label: "On Order", tint: .blue, icon: "clock.badge.fill")
            }

            let vehicleNames = compatibleVehicleNames(for: part)
            if !vehicleNames.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Compatible Vehicles")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                    FlexibleTags(values: vehicleNames)
                }
            }

            if part.pendingApprovals > 0 || part.pendingDeliveryCount > 0 {
                HStack(spacing: 10) {
                    if part.pendingApprovals > 0 {
                        Label("\(part.pendingApprovals) pending approval", systemImage: "clock.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.orange)
                    }
                    if part.pendingDeliveryCount > 0 {
                        Label("\(part.pendingDeliveryCount) awaiting delivery", systemImage: "shippingbox.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.blue)
                    }
                    Spacer()
                }

                if let eta = part.expectedArrival {
                    Text("Expected by \(eta.formatted(.dateTime.day().month(.abbreviated).hour().minute()))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    partDetailMode = .request
                    selectedPart = part
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Request For")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.appOrange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.appOrange.opacity(0.10)))
                    .overlay(Capsule().stroke(Color.appOrange.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    partDetailMode = .placeOrder
                    selectedPart = part
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Place Order")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.blue))
                }
                .buttonStyle(.plain)
            }
        }
        .onTapGesture {
            partDetailMode = .request
            selectedPart = part
        }
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

    private func metricLine(value: Int, label: String, tint: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text("\(max(0, value))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.3))
            Text("No Parts")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            Text("Parts catalog for your assigned maintenance tasks\nwill appear here.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
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
    enum ActionMode: String, CaseIterable {
        case request = "Request For"
        case placeOrder = "Place Order"
    }

    let part: InventoryView.PartInventorySnapshot
    let initialMode: ActionMode
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var actionMode: ActionMode = .request
    @State private var requestQty: Int = 1
    @State private var orderQty: Int = 1
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var etaDate: Date = Date().addingTimeInterval(2 * 24 * 3600)

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }
    private var myOpenTask: MaintenanceTask? {
        store.maintenanceTasks.first {
            $0.assignedToId == currentUserId && ($0.status == .assigned || $0.status == .inProgress)
        }
    }
    private var userRole: UserRole? { AuthManager.shared.currentUser?.role }
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
    private var canPlaceDirectOrder: Bool { userRole == .fleetManager }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(part.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    if let pn = part.partNumber, !pn.isEmpty {
                        Text("Part Code: \(pn)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if let supplier = part.supplier, !supplier.isEmpty {
                        Text("Supplier: \(supplier)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
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
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                        FlexibleTags(values: part.compatibleVehicleIds.compactMap { id in
                            guard let v = store.vehicle(for: id) else { return nil }
                            return "\(v.name) (\(v.licensePlate))"
                        })
                    }
                }

                if !recentRequests.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Order Activity")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                        ForEach(Array(recentRequests.prefix(3))) { req in
                            HStack {
                                Text(req.status.rawValue)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(statusTint(req.status))
                                Spacer()
                                Text(req.createdAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.appCardBg))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.5), lineWidth: 1))
                }

                Picker("Action", selection: $actionMode) {
                    ForEach(ActionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(
                    actionMode == .request ? "Request Quantity: \(requestQty)" : "Order Quantity: \(orderQty)",
                    value: actionMode == .request ? $requestQty : $orderQty,
                    in: 1...500
                )

                TextField("Reason / notes", text: $note)
                    .textFieldStyle(.roundedBorder)

                DatePicker("Expected ETA", selection: $etaDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)

                HStack(spacing: 10) {
                    Button {
                        actionMode = .request
                        Task { await submitPartRequest(orderRequest: false) }
                    } label: {
                        Text("Request For")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appOrange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.appOrange.opacity(0.1)))
                            .overlay(Capsule().stroke(Color.appOrange.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting || myOpenTask == nil)

                    Button {
                        actionMode = .placeOrder
                        Task { await submitPartRequest(orderRequest: true) }
                    } label: {
                        Text("Place Order")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(canPlaceDirectOrder ? Color.blue : Color.appOrange))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting || myOpenTask == nil)
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
        .onAppear {
            actionMode = initialMode
            orderQty = max(1, max(0, requestQty))
        }
    }

    private func statLine(_ label: String, _ value: String, tint: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    private func submitPartRequest(orderRequest: Bool) async {
        guard let task = myOpenTask else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let quantity = orderRequest ? orderQty : requestQty
        let reasonPrefix = orderRequest
            ? "Order request from inventory detail"
            : "Requested from inventory detail"
        let request = SparePartsRequest(
            id: UUID(),
            maintenanceTaskId: task.id,
            workOrderId: store.workOrder(forMaintenanceTask: task.id)?.id,
            requestedById: currentUserId,
            partName: part.name,
            partNumber: part.partNumber,
            quantity: quantity,
            estimatedUnitCost: nil,
            supplier: part.supplier,
            reason: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? reasonPrefix
                : "\(reasonPrefix): \(note)",
            status: .pending,
            quantityAvailable: inStock,
            quantityAllocated: 0,
            quantityOnOrder: orderRequest ? quantity : part.onOrderQty,
            createdAt: Date(),
            updatedAt: Date(),
            expectedArrivalAt: orderRequest ? etaDate : nil
        )
        try? await store.addSparePartsRequest(request)
        if canPlaceDirectOrder, orderRequest,
           let inv = store.inventoryParts.first(where: {
               $0.partName.caseInsensitiveCompare(part.name) == .orderedSame &&
               (($0.partNumber ?? "").lowercased() == (part.partNumber ?? "").lowercased())
           }) {
            try? await store.updateInventoryPart(
                id: inv.id,
                partName: inv.partName,
                partNumber: inv.partNumber,
                supplier: inv.supplier,
                category: inv.category,
                unit: inv.unit,
                currentQuantity: inv.currentQuantity,
                reorderLevel: inv.reorderLevel,
                onOrderQuantity: inv.onOrderQuantity + quantity,
                expectedArrivalAt: etaDate,
                compatibleVehicleIds: inv.compatibleVehicleIds,
                isActive: inv.isActive
            )
        }
        dismiss()
    }

    private func statusTint(_ status: SparePartsRequestStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        case .fulfilled: return .blue
        }
    }
}

private struct FlexibleTags: View {
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(values.prefix(3).enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.appDivider.opacity(0.35)))
            }
            if values.count > 3 {
                Text("+\(values.count - 3) more")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appOrange)
            }
        }
    }
}
