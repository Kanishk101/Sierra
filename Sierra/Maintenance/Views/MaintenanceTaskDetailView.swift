import SwiftUI
import PhotosUI

/// Detail view for a maintenance task — shows task info, vehicle card,
/// status timeline, work order form, and action buttons.
struct MaintenanceTaskDetailView: View {

    let task: MaintenanceTask
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MaintenanceTaskDetailViewModel

    @State private var repairImageItems: [PhotosPickerItem] = []
    @State private var showError = false
    @State private var showSparePartsSheet = false
    @State private var showVINScanner = false
    @State private var scannedVIN = ""
    @State private var vinLookupError: String?
    @State private var vinLookupVehicle: Vehicle?

    init(task: MaintenanceTask) {
        self.task = task
        _viewModel = State(initialValue: MaintenanceTaskDetailViewModel(task: task))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                taskHeader
                vehicleCard
                statusTimeline
                Divider()

                actionSection

                if viewModel.workOrder != nil {
                    workOrderForm
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Task Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadExistingWorkOrder()
        }
        .onChange(of: viewModel.errorMessage) { _, msg in
            showError = (msg != nil)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong")
        }
        .sheet(isPresented: $showSparePartsSheet) {
            if let wo = viewModel.workOrder {
                SparePartsRequestSheet(maintenanceTaskId: task.id, workOrderId: wo.id)
            }
        }
        .sheet(isPresented: $showVINScanner) {
            NavigationStack {
                VINScannerView(scannedVIN: $scannedVIN)
            }
        }
        .onChange(of: scannedVIN) { _, vin in
            if !vin.isEmpty {
                if let vehicle = store.vehicles.first(where: { $0.vin.uppercased() == vin.uppercased() }) {
                    vinLookupVehicle = vehicle
                    vinLookupError = nil
                } else {
                    vinLookupVehicle = nil
                    vinLookupError = "No vehicle found with VIN: \(vin)"
                }
            }
        }
    }

    // MARK: - Task Header

    private var taskHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                    .font(.title3.weight(.bold))
                Spacer()
                priorityBadge
            }
            Text(task.taskDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label(task.taskType.rawValue, systemImage: "tag")
                Label(task.dueDate.formatted(.dateTime.month(.abbreviated).day().year()), systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var priorityBadge: some View {
        Text(task.priority.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(priorityColor, in: Capsule())
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    // MARK: - Vehicle Card

    private var vehicleCard: some View {
        let vehicle = store.vehicles.first(where: { $0.id == task.vehicleId })
        return VStack(alignment: .leading, spacing: 8) {
            Text("VEHICLE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary).kerning(1)
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.title2).foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle?.name ?? "Unknown").font(.subheadline.weight(.medium))
                    Text("\(vehicle?.licensePlate ?? "") • \(vehicle?.model ?? "")").font(.caption).foregroundStyle(.secondary)
                    Text("VIN: \(vehicle?.vin ?? "N/A")").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                    Text("Odometer: \(vehicle?.odometer ?? 0, specifier: "%.0f") km").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }

            // VIN Scanner
            HStack(spacing: 8) {
                Button {
                    showVINScanner = true
                } label: {
                    Label("Scan VIN", systemImage: "barcode.viewfinder")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.orange, in: Capsule())
                }

                if let v = vinLookupVehicle {
                    Label("\(v.name) matched", systemImage: "checkmark.circle.fill")
                        .font(.caption2).foregroundStyle(.green)
                }
                if let err = vinLookupError {
                    Text(err).font(.caption2).foregroundStyle(.red)
                }
            }.padding(.top, 4)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Status Timeline

    private var statusTimeline: some View {
        let steps: [(String, MaintenanceTaskStatus)] = [
            ("Pending", .pending),
            ("Assigned", .assigned),
            ("In Progress", .inProgress),
            ("Completed", .completed)
        ]
        let currentIndex = steps.firstIndex(where: { $0.1 == task.status }) ?? 0

        return VStack(alignment: .leading, spacing: 0) {
            Text("STATUS").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)
                .padding(.bottom, 8)

            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(idx <= currentIndex ? Color.orange : Color(.systemGray4))
                            .frame(width: 12, height: 12)
                        Text(step.0)
                            .font(.system(size: 9, weight: idx <= currentIndex ? .bold : .regular))
                            .foregroundStyle(idx <= currentIndex ? .primary : .secondary)
                    }
                    if idx < steps.count - 1 {
                        Rectangle()
                            .fill(idx < currentIndex ? Color.orange : Color(.systemGray4))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionSection: some View {
        if task.status == .assigned && viewModel.workOrder == nil {
            Button {
                Task {
                    await viewModel.startWork()
                }
            } label: {
                HStack {
                    if viewModel.isStartingWork { ProgressView().tint(.white) }
                    Text("Start Work")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(SierraTheme.Colors.ember, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(viewModel.isStartingWork)
        }
    }

    // MARK: - Work Order Form

    private var workOrderForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WORK ORDER").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)

            VStack(alignment: .leading, spacing: 8) {
                Text("Repair Description").font(.caption.weight(.medium))
                TextEditor(text: $viewModel.repairDescription)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            DatePicker("Est. Completion", selection: $viewModel.estimatedCompletion, displayedComponents: [.date, .hourAndMinute])
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Parts Used").font(.caption.weight(.medium))
                    Spacer()
                    Button {
                        viewModel.addPartRow()
                    } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.orange)
                    }
                }
                ForEach($viewModel.partsUsed) { $part in
                    HStack(spacing: 8) {
                        TextField("Part", text: $part.name).textFieldStyle(.roundedBorder).font(.caption)
                        TextField("#", text: $part.partNumber).textFieldStyle(.roundedBorder).font(.caption).frame(width: 60)
                        Stepper("Qty: \(part.quantity)", value: $part.quantity, in: 1...100).font(.caption2)
                        TextField("Cost", value: $part.unitCost, format: .number).textFieldStyle(.roundedBorder).font(.caption).frame(width: 60)
                    }
                }
                Text("Parts Total: ₹\(viewModel.computedPartsCost, specifier: "%.2f")")
                    .font(.caption.weight(.bold)).foregroundStyle(.orange)
            }

            Button("Request Spare Parts") {
                showSparePartsSheet = true
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(SierraTheme.Colors.info)

            VStack(alignment: .leading, spacing: 8) {
                Text("Repair Images").font(.caption.weight(.medium))
                PhotosPicker(selection: $repairImageItems, maxSelectionCount: 5, matching: .images) {
                    Label("Add Photos", systemImage: "camera.fill")
                        .font(.subheadline)
                        .foregroundStyle(SierraTheme.Colors.info)
                }
                .onChange(of: repairImageItems) { _, items in
                    Task { await viewModel.uploadRepairImages(items) }
                }
                if viewModel.isUploadingImages {
                    ProgressView("Uploading images...")
                }
                if !viewModel.repairImageUrls.isEmpty {
                    Text("\(viewModel.repairImageUrls.count) image(s) uploaded").font(.caption).foregroundStyle(.green)
                }
            }

            HStack {
                Text("Labour Cost").font(.caption.weight(.medium))
                Spacer()
                TextField("₹", value: $viewModel.labourCost, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 100)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Technician Notes").font(.caption.weight(.medium))
                TextEditor(text: $viewModel.technicianNotes)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            if task.status == .inProgress || viewModel.workOrder != nil {
                Button {
                    Task {
                        let completed = await viewModel.markComplete()
                        if completed { dismiss() }
                    }
                } label: {
                    HStack {
                        if viewModel.isCompleting { ProgressView().tint(.white) }
                        Text("Mark Complete")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(SierraTheme.Colors.alpineMint, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.isCompleting)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
