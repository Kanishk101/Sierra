import SwiftUI

// MARK: - RepairTaskListView

struct RepairTaskListView: View {
    @Environment(AppDataStore.self) private var store
    @State private var statusFilter: MaintenanceTaskStatus? = nil
    @State private var searchText = ""
    @State private var showProfile = false
    @State private var vehicleSheetVehicle: Vehicle?

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    /// Repair tasks only (non-scheduled)
    private var repairTasks: [MaintenanceTask] {
        store.maintenanceTasks.filter { task in
            task.assignedToId == currentUserId && task.taskType != .scheduled
        }
    }

    private var filteredTasks: [MaintenanceTask] {
        repairTasks.filter { task in
            if let f = statusFilter, task.status != f { return false }
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if q.isEmpty { return true }
            let vehicle = store.vehicle(for: task.vehicleId)
            let idText = "MNT-\(task.id.uuidString.prefix(8).uppercased())".lowercased()
            let blob = "\(task.title) \(task.taskDescription) \(vehicle?.licensePlate ?? "") \(vehicle?.name ?? "")".lowercased()
            return idText.contains(q) || blob.contains(q)
        }
    }

    private var isFilterActive: Bool { statusFilter != nil }
    private var totalCount: Int { repairTasks.count }
    private var activeCount: Int { repairTasks.filter { $0.status == .assigned || $0.status == .inProgress }.count }
    private var completedCount: Int { repairTasks.filter { $0.status == .completed }.count }

    var body: some View {
        VStack(spacing: 10) {
            searchBar
            statsRow

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredTasks) { task in
                        NavigationLink(value: task) {
                            TaskCard(task: task, store: store)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .overlay {
            if filteredTasks.isEmpty { emptyState }
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Repairs")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { profileButton }
            ToolbarItem(placement: .topBarTrailing) { filterMenuButton }
        }
        .navigationDestination(for: MaintenanceTask.self) { task in
            MaintenanceTaskDetailView(task: task)
        }
        .sheet(isPresented: $showProfile) {
            MaintenanceProfileView()
                .environment(store)
        }
        .sheet(item: $vehicleSheetVehicle) { vehicle in
            VehicleQuickStatusSheet(vehicle: vehicle)
                .environment(store)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.appTextSecondary)
            TextField("Search task ID, vehicle, title", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statPill(value: totalCount, label: "Total", color: Color.appOrange, icon: "list.bullet.rectangle.fill")
            statPill(value: activeCount, label: "Active", color: .blue, icon: "clock.fill")
            statPill(value: completedCount, label: "Done", color: .green, icon: "checkmark.seal.fill")
        }
        .padding(.horizontal, 16)
    }

    private func statPill(value: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text("\(value)").font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Filter Menu

    private var filterMenuButton: some View {
        Menu {
            Button {
                statusFilter = nil
            } label: {
                Label("All", systemImage: statusFilter == nil ? "checkmark" : "")
            }
            Divider()
            ForEach(MaintenanceTaskStatus.allCases, id: \.self) { status in
                Button {
                    statusFilter = (statusFilter == status) ? nil : status
                } label: {
                    Label(status.rawValue, systemImage: statusFilter == status ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle\(isFilterActive ? ".fill" : "")")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.appOrange)
        }
    }

    private var profileButton: some View {
        Button { showProfile = true } label: {
            if let staffer = store.staff.first(where: { $0.id == AuthManager.shared.currentUser?.id }) {
                let initials = initials(for: staffer.name ?? "MP")
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appOrange, Color.appDeepOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    Text(initials)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.appOrange)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle" : "wrench.and.screwdriver")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.3))
            Text(isFilterActive ? "No Matches" : "No Repair Tasks")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            Text(isFilterActive ? "Try a different filter." : "No assigned repair tasks right now.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
            if isFilterActive {
                Button { statusFilter = nil } label: {
                    Text("Clear Filter")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appOrange)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.appOrange.opacity(0.1), in: Capsule())
                }
            }
        }
        .padding(40)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        switch parts.count {
        case 0:  return "?"
        case 1:  return String(parts[0].prefix(2)).uppercased()
        default: return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
    }
}

// MARK: - Task Type Filter

enum TaskTypeFilter: Int, CaseIterable {
    case all = 0
    case repair = 1
    case service = 2
}

// MARK: - Vehicle Quick Status Sheet

struct VehicleQuickStatusSheet: View {
    let vehicle: Vehicle
    @Environment(AppDataStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    vehicleHeader
                    detailsCard
                    documentsCard
                    inspectionsCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.appSurface.ignoresSafeArea())
            .navigationTitle("Vehicle")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Header

    private var vehicleHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(statusColor(vehicle.status).opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "car.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(statusColor(vehicle.status))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                Text("\(vehicle.licensePlate) · \(vehicle.manufacturer) \(vehicle.model)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Text(vehicle.status.rawValue)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(statusColor(vehicle.status), in: Capsule())
        }
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "Odometer", value: "\(Int(vehicle.odometer)) km", icon: "gauge.with.dots.needle.bottom.50percent")
            Divider().padding(.leading, 44)
            detailRow(label: "VIN", value: vehicle.vin, icon: "barcode")
            Divider().padding(.leading, 44)
            detailRow(label: "Year", value: "\(vehicle.year)", icon: "calendar")
            Divider().padding(.leading, 44)
            detailRow(label: "Fuel", value: vehicle.fuelType.rawValue, icon: "fuelpump.fill")
            if vehicle.totalTrips > 0 {
                Divider().padding(.leading, 44)
                detailRow(label: "Trips", value: "\(vehicle.totalTrips)", icon: "arrow.triangle.swap")
            }
            if vehicle.totalDistanceKm > 0 {
                Divider().padding(.leading, 44)
                detailRow(label: "Distance", value: "\(Int(vehicle.totalDistanceKm)) km", icon: "road.lanes")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.appDivider, lineWidth: 1)
        )
    }

    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.appOrange)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - Documents Card

    @ViewBuilder
    private var documentsCard: some View {
        let docs = store.vehicleDocuments.filter { $0.vehicleId == vehicle.id }
        if !docs.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(docs.enumerated()), id: \.element.id) { idx, doc in
                    HStack(spacing: 12) {
                        Image(systemName: docIcon(doc))
                            .font(.system(size: 14))
                            .foregroundStyle(docColor(doc))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.documentType.rawValue)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.appTextPrimary)
                            Text("Expires \(doc.expiryDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        if doc.isExpired {
                            Text("EXPIRED")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.red.opacity(0.1), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    if idx < docs.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.appCardBg)
                    .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.appDivider, lineWidth: 1)
            )
        }
    }

    // MARK: - Inspections Card

    @ViewBuilder
    private var inspectionsCard: some View {
        let inspections = Array(store.vehicleInspections.filter { $0.vehicleId == vehicle.id }.prefix(3))
        if !inspections.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(inspections.enumerated()), id: \.element.id) { idx, insp in
                    HStack(spacing: 12) {
                        Image(systemName: inspIcon(insp.overallResult))
                            .font(.system(size: 16))
                            .foregroundStyle(inspColor(insp.overallResult))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(insp.type.rawValue)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.appTextPrimary)
                            Text(insp.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        Text(insp.overallResult.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(inspColor(insp.overallResult))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(inspColor(insp.overallResult).opacity(0.1), in: Capsule())
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    if idx < inspections.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.appCardBg)
                    .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.appDivider, lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private func statusColor(_ s: VehicleStatus) -> Color {
        switch s {
        case .active: return .green
        case .idle: return .blue
        case .busy: return .purple
        case .inMaintenance: return .orange
        case .outOfService: return .red
        case .decommissioned: return .gray
        }
    }

    private func docIcon(_ doc: VehicleDocument) -> String {
        if doc.isExpired { return "exclamationmark.triangle.fill" }
        if doc.isExpiringSoon { return "clock.badge.exclamationmark" }
        return "doc.fill"
    }

    private func docColor(_ doc: VehicleDocument) -> Color {
        if doc.isExpired { return .red }
        if doc.isExpiringSoon { return .orange }
        return .green
    }

    private func inspIcon(_ result: InspectionResult) -> String {
        switch result {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private func inspColor(_ result: InspectionResult) -> Color {
        switch result {
        case .passed: return .green
        case .failed: return .red
        default: return .orange
        }
    }
}
