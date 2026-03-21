import SwiftUI
import AVFoundation

/// Full maintenance dashboard showing assigned tasks with filters.
/// Replaces the skeleton placeholder.
struct MaintenanceDashboardView: View {
    @State private var selectedTab: MaintenanceTab = .tasks
    @State private var viewModel = MaintenanceDashboardViewModel()
    @State private var showNotifications = false
    @State private var showEditProfile = false
    @State private var scannedVIN: String?
    @State private var isScanning = true
    @Environment(AppDataStore.self) private var store

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    enum MaintenanceTab: Int, CaseIterable {
        case tasks, workOrders, vinScanner, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            tasksTab
                .tag(MaintenanceTab.tasks)
                .tabItem {
                    Image(systemName: "list.clipboard.fill")
                    Text("Tasks")
                }

            workOrdersTab
                .tag(MaintenanceTab.workOrders)
                .tabItem {
                    Image(systemName: "doc.plaintext.fill")
                    Text("Work Orders")
                }

            vinScannerTab
                .tag(MaintenanceTab.vinScanner)
                .tabItem {
                    Image(systemName: "barcode.viewfinder")
                    Text("VIN Scanner")
                }

            profileTab
                .tag(MaintenanceTab.profile)
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Profile")
                }
        }
        .tint(.orange)
    }

    // MARK: - Tasks Tab

    private var tasksTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                filterBar

                // Vehicle chips
                if !viewModel.uniqueVehicleIds.isEmpty {
                    vehicleChips
                }

                // Task list
                if viewModel.isLoading && viewModel.assignedTasks.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.filteredTasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Tasks")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.caption2)
                        Text("\(viewModel.filteredTasks.count)")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1), in: Capsule())
                }
            }
            .task {
                await viewModel.loadTasks(for: currentUserId)
            }
            .refreshable {
                await viewModel.refresh(for: currentUserId)
            }
            .navigationDestination(for: UUID.self) { taskId in
                if let task = viewModel.assignedTasks.first(where: { $0.id == taskId }) {
                    MaintenanceTaskDetailView(task: task)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNotifications = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill").font(.body).foregroundStyle(.primary)
                            if store.unreadNotificationCount > 0 {
                                Text("\(store.unreadNotificationCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(.red, in: Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationCentreView()
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        Picker("Filter", selection: Binding(
            get: { viewModel.selectedFilter },
            set: { viewModel.filterByStatus($0) }
        )) {
            ForEach(MaintenanceDashboardViewModel.TaskFilter.allCases, id: \.self) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Vehicle Chips

    private var vehicleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "All Vehicles", isSelected: viewModel.selectedVehicleFilter == nil) {
                    viewModel.filterByVehicle(nil)
                }
                ForEach(viewModel.uniqueVehicleIds, id: \.self) { vId in
                    let vehicle = store.vehicles.first(where: { $0.id == vId })
                    chipButton(
                        label: vehicle?.licensePlate ?? vId.uuidString.prefix(8).description,
                        isSelected: viewModel.selectedVehicleFilter == vId
                    ) {
                        viewModel.filterByVehicle(vId)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.orange : Color(.secondarySystemBackground), in: Capsule())
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        List {
            ForEach(viewModel.filteredTasks) { task in
                NavigationLink(value: task.id) {
                    taskRow(task)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func taskRow(_ task: MaintenanceTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    let vehicle = store.vehicles.first(where: { $0.id == task.vehicleId })
                    Text("\(vehicle?.name ?? "Vehicle") • \(vehicle?.licensePlate ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                priorityBadge(task.priority)
            }

            HStack(spacing: 12) {
                statusBadge(task.status)
                Spacer()
                Label(task.dueDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(timeAgo(task.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func priorityBadge(_ priority: TaskPriority) -> some View {
        Text(priority.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(priorityColor(priority), in: Capsule())
    }

    private func statusBadge(_ status: MaintenanceTaskStatus) -> some View {
        HStack(spacing: 4) {
            Circle().fill(statusColor(status)).frame(width: 6, height: 6)
            Text(status.rawValue)
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusColor(status))
        }
    }

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    private func statusColor(_ s: MaintenanceTaskStatus) -> Color {
        switch s {
        case .pending: return .orange
        case .assigned: return .blue
        case .inProgress: return .purple
        case .completed: return .green
        case .cancelled: return .gray
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.orange.opacity(0.4))
            Text("No tasks match this filter")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Coming Soon (unchanged)

    private func comingSoonTab(icon: String, title: String, subtitle: String) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.orange.opacity(0.5))
                Text(title).font(.title3.weight(.semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 48)
                Text("Coming Soon")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.1), in: Capsule())
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }
    // MARK: - Work Orders Tab

    private var myWorkOrders: [WorkOrder] {
        store.workOrders.filter { $0.assignedToId == currentUserId }
    }

    private func workOrders(for status: WorkOrderStatus) -> [WorkOrder] {
        myWorkOrders.filter { $0.status == status }
    }

    private var workOrdersTab: some View {
        NavigationStack {
            Group {
                if myWorkOrders.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(.orange.opacity(0.4))
                        Text("No work orders assigned")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(WorkOrderStatus.allCases, id: \.self) { status in
                            let orders = workOrders(for: status)
                            if !orders.isEmpty {
                                Section {
                                    ForEach(orders) { wo in
                                        let parentTask = store.maintenanceTasks.first { $0.id == wo.maintenanceTaskId }
                                        let vehicle = store.vehicles.first { $0.id == wo.vehicleId }
                                        NavigationLink(value: wo.maintenanceTaskId) {
                                            workOrderRow(wo, vehicle: vehicle, task: parentTask)
                                        }
                                    }
                                } header: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(workOrderStatusColor(status))
                                            .frame(width: 8, height: 8)
                                        Text(status.rawValue)
                                            .font(.subheadline.weight(.semibold))
                                        Text("(\(workOrders(for: status).count))")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Work Orders")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.caption2)
                        Text("\(myWorkOrders.count)")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1), in: Capsule())
                }
            }
            .refreshable {
                await store.loadMaintenanceData(staffId: currentUserId)
            }
            .navigationDestination(for: UUID.self) { taskId in
                if let task = store.maintenanceTasks.first(where: { $0.id == taskId }) {
                    MaintenanceTaskDetailView(task: task)
                }
            }
        }
    }

    private func workOrderRow(_ wo: WorkOrder, vehicle: Vehicle?, task: MaintenanceTask?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task?.title ?? "Work Order")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let vehicle {
                        Text("\(vehicle.name) • \(vehicle.licensePlate)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(wo.status.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(workOrderStatusColor(wo.status), in: Capsule())
            }

            HStack(spacing: 12) {
                if wo.vinScanned {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        Text("VIN Scanned")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                Spacer()
                if let est = wo.estimatedCompletionAt {
                    Label(est.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(timeAgo(wo.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func workOrderStatusColor(_ status: WorkOrderStatus) -> Color {
        switch status {
        case .open:       .blue
        case .inProgress: .purple
        case .onHold:     .orange
        case .completed:  .green
        case .closed:     .gray
        }
    }

    // MARK: - VIN Scanner Tab

    private var vinScannerTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isScanning {
                    ZStack {
                        BarcodeScannerView { code in
                            scannedVIN = code
                            isScanning = false
                            markWorkOrdersScanned(vin: code)
                        }
                        .ignoresSafeArea()

                        VStack {
                            Spacer()
                            Text("Align barcode within view")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(.bottom, 40)
                        }
                    }
                } else if let vin = scannedVIN {
                    scanResultView(vin: vin)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("VIN Scanner")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }

    @ViewBuilder
    private func scanResultView(vin: String) -> some View {
        let matchedVehicle = store.vehicles.first { $0.vin == vin }
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "barcode")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scanned VIN").font(.caption).foregroundStyle(.secondary)
                        Text(vin).font(.system(.body, design: .monospaced, weight: .semibold))
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                if let vehicle = matchedVehicle {
                    HStack(spacing: 14) {
                        Image(systemName: "car.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 48, height: 48)
                            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(vehicle.name).font(.headline)
                            Text(vehicle.licensePlate).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(vehicle.status.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                    let openOrders = store.workOrders.filter { $0.vehicleId == vehicle.id && $0.status != .closed }
                    if openOrders.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("No open work orders").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Open Work Orders (\(openOrders.count))")
                                .font(.headline)
                                .padding(.top, 8)
                            ForEach(openOrders) { wo in
                                HStack(spacing: 12) {
                                    Image(systemName: wo.vinScanned ? "checkmark.circle.fill" : "wrench.fill")
                                        .foregroundStyle(wo.vinScanned ? .green : .orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(wo.repairDescription.isEmpty ? "Work Order" : wo.repairDescription)
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(1)
                                        Text(wo.status.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if wo.vinScanned {
                                        Text("Scanned")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(.green, in: Capsule())
                                    }
                                }
                                .padding(12)
                                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.orange)
                        Text("Vehicle Not Found")
                            .font(.headline)
                        Text("No vehicle matches VIN \"\(vin)\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)
                }

                Button {
                    scannedVIN = nil
                    isScanning = true
                } label: {
                    Label("Scan Again", systemImage: "barcode.viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
    }

    private func markWorkOrdersScanned(vin: String) {
        guard let vehicle = store.vehicles.first(where: { $0.vin == vin }) else { return }
        let openOrders = store.workOrders.filter { $0.vehicleId == vehicle.id && $0.status != .closed && !$0.vinScanned }
        for wo in openOrders {
            Task {
                try? await WorkOrderService.setVinScanned(workOrderId: wo.id)
                if let idx = store.workOrders.firstIndex(where: { $0.id == wo.id }) {
                    store.workOrders[idx].vinScanned = true
                }
            }
        }
    }

    // MARK: - Profile Tab

    private var profileTab: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                let user = AuthManager.shared.currentUser
                let initials = (user?.name ?? "M").prefix(2).uppercased()
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    )
                VStack(spacing: 6) {
                    Text(user?.name ?? "Maintenance Staff").font(.title3.weight(.semibold))
                    Text(user?.email ?? "").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "wrench.fill").font(.caption2)
                    Text("Maintenance Personnel").font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Color.blue.opacity(0.06), in: Capsule())

                HStack(spacing: 8) {
                    Image(systemName: user?.isApproved == true ? "checkmark.seal.fill" : "clock.fill")
                        .foregroundStyle(user?.isApproved == true ? .green : .orange)
                    Text(user?.isApproved == true ? "Approved" : "Pending Approval").font(.subheadline)
                }
                .padding(16).frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)

                NavigationLink {
                    ChangePasswordView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.rotation")
                        Text("Change Password")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 48)
                    .padding(.horizontal, 16)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

                Spacer()
                Button {
                    AuthManager.shared.signOut()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right").font(.caption)
                        Text("Sign Out").font(.subheadline)
                    }
                    .foregroundStyle(.red.opacity(0.7))
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Profile")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEditProfile = true }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                NavigationStack {
                    MaintenanceProfileEditView()
                }
            }
        }
    }
}

#Preview {
    MaintenanceDashboardView()
}

// MARK: - Barcode Scanner UIViewRepresentable

private struct BarcodeScannerView: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onCodeScanned = onCodeScanned
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

private class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showFallback("Camera not available")
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.code39, .ean13, .code128]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue, !value.isEmpty else { return }
        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onCodeScanned?(value)
    }

    private func showFallback(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
