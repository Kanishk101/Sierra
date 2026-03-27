import SwiftUI

/// Admin detail view for a maintenance task.
/// Sierra design system: no description in overview, driver dual-button actions,
/// clean timeline, appCardBg throughout.
struct MaintenanceApprovalDetailView: View {

    let task: MaintenanceTask
    var onUpdate: () -> Void

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var rejectionReason = ""
    @State private var isApproving = false
    @State private var isRejecting = false
    @State private var isAssigning = false
    @State private var showRejectSheet = false
    @State private var showAssignSheet = false
    @State private var showVehicleSheet = false
    @State private var showWorkOrderSheet = false
    @State private var fetchedWorkOrder: WorkOrder?
    @State private var loadedPhases = false
    @State private var rejectPartTarget: SparePartsRequest?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showAssigneeDetails = false
    @State private var showVehicleDetails = false
    @State private var expandedPhases: Set<UUID> = []
    @State private var orderingPartTarget: SparePartsRequest?
    @State private var orderArrivalAt: Date = Date().addingTimeInterval(48 * 3600)
    @State private var orderReference: String = ""

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var availableStaff: [StaffMember] {
        store.staff.filter { $0.role == .maintenancePersonnel && $0.status == .active && $0.availability == .available }
    }
    private var isApprovedAwaitingAssignment: Bool {
        task.isApprovedAwaitingAssignment
    }

    private var workOrder: WorkOrder? { store.workOrder(forMaintenanceTask: task.id) ?? fetchedWorkOrder }
    private var vehicle: Vehicle? { store.vehicle(for: task.vehicleId) }
    private var reportedBy: StaffMember? { store.staffMember(for: task.createdByAdminId) }
    private var linkedInspection: VehicleInspection? {
        guard let id = task.sourceInspectionId else { return nil }
        return store.vehicleInspections.first(where: { $0.id == id })
    }
    private var evidencePhotoUrls: [String] {
        if let urls = linkedInspection?.photoUrls, !urls.isEmpty {
            return urls
        }
        return extractURLs(from: task.taskDescription)
    }
    private var phases: [WorkOrderPhase] { guard let wo = workOrder else { return [] }; return store.phases(forWorkOrder: wo.id) }
    private var spareParts: [SparePartsRequest] { store.sparePartsRequests(forTask: task.id).sorted { $0.createdAt > $1.createdAt } }
    private var donePhases: Int { phases.filter(\.isCompleted).count }

    private var progressValue: Double {
        let base: Double
        switch task.status {
        case .pending: base = 0.15; case .assigned: base = 0.32
        case .inProgress: base = 0.55; case .completed: base = 1.0; case .cancelled: base = 0.0
        }
        guard !phases.isEmpty else { return base }
        return max(base, Double(donePhases) / Double(phases.count))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusStripCard
                overviewCard
                issueEvidenceCard
                assignmentFleetCard
                timelineCard
                if !spareParts.isEmpty { partsCard }
                actionCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Task Overview")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .task { await loadData() }
        .sheet(isPresented: $showRejectSheet) { rejectSheet }
        .sheet(isPresented: $showWorkOrderSheet) {
            WorkOrderDetailSheet(task: task).environment(store)
        }
        .navigationDestination(isPresented: $showAssignSheet) {
            AssignTechnicianScreen(candidates: availableStaff) { staffId in
                Task { await assignApprovedTask(to: staffId) }
            }
        }
        .sheet(item: $rejectPartTarget) { part in
            RejectPartReasonSheet(part: part) { reason in
                Task { try? await store.rejectSparePartsRequest(id: part.id, reviewedBy: currentUserId, reason: reason) }
            }
        }
        .sheet(item: $orderingPartTarget) { part in
            let inventoryMatch = store.inventoryParts.first {
                $0.partName.caseInsensitiveCompare(part.partName) == .orderedSame
                    && (($0.partNumber ?? "").caseInsensitiveCompare(part.partNumber ?? "") == .orderedSame)
            }
            let compatibleVehicles = (inventoryMatch?.compatibleVehicleIds ?? []).compactMap { id -> String? in
                guard let vehicle = store.vehicle(for: id) else { return nil }
                return "\(vehicle.name) (\(vehicle.licensePlate))"
            }
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Order Part")
                        .font(SierraFont.scaled(16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)

                    VStack(alignment: .leading, spacing: 10) {
                        orderLabeledValue("Part Name", part.partName)
                        orderLabeledValue("Part Number", (part.partNumber ?? "").isEmpty ? "N/A" : (part.partNumber ?? "N/A"))
                        orderLabeledValue("Supplier", inventoryMatch?.supplier ?? "N/A")
                        orderLabeledValue("Category", inventoryMatch?.category ?? "N/A")
                        orderLabeledValue("Current Stock", "\(max(0, inventoryMatch?.currentQuantity ?? part.quantityAvailable))")
                        orderLabeledValue("Required Qty", "\(part.quantity)")
                        orderLabeledValue("Qty To Order", "\(max(0, part.quantity - part.quantityAllocated))")
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.appCardBg))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appDivider.opacity(0.45), lineWidth: 1))

                    if !compatibleVehicles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compatible Vehicles")
                                .font(SierraFont.scaled(12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appTextSecondary)
                            ForEach(Array(compatibleVehicles.prefix(4)), id: \.self) { name in
                                Text(name)
                                    .font(SierraFont.scaled(11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.appTextSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.appDivider.opacity(0.35)))
                            }
                        }
                    }

                    DatePicker(
                        "Expected Arrival",
                        selection: $orderArrivalAt,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)

                    TextField("Order reference (optional)", text: $orderReference)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            try? await store.placeOrderForPartRequest(
                                id: part.id,
                                reviewedBy: currentUserId,
                                expectedArrivalAt: orderArrivalAt,
                                orderReference: orderReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? nil
                                    : orderReference.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            orderingPartTarget = nil
                            orderReference = ""
                        }
                    } label: {
                        Text("Confirm Place Order")
                            .font(SierraFont.scaled(14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appTextPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(20)
                .background(Color.appSurface.ignoresSafeArea())
                .navigationTitle("Place Order")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { orderingPartTarget = nil }
                            .foregroundStyle(Color.appOrange)
                    }
                }
            }
            .presentationDetents([.large])
            .onAppear {
                orderArrivalAt = part.expectedArrivalAt ?? Date().addingTimeInterval(48 * 3600)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Status Strip

    private var statusStripCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(statusColor(task.status)).frame(width: 8, height: 8)
                    Text(task.isEffectivelyAssigned ? MaintenanceTaskStatus.assigned.rawValue : task.status.rawValue)
                        .font(SierraFont.scaled(13, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor(task.status))
                }
                Spacer()
            }

            HStack {
                Text("Task Progress")
                    .font(SierraFont.scaled(12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                Text("\(Int(progressValue * 100))%")
                    .font(SierraFont.scaled(12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.appDivider.opacity(0.8))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(task.status == .completed ? Color.green : Color.appOrange)
                        .frame(width: geo.size.width * progressValue)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Overview Card (NO description)

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(SierraFont.scaled(19, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("MNT-\(task.id.uuidString.prefix(8).uppercased())")
                        .font(SierraFont.scaled(11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.appOrange)
                }
                Spacer()
                typeBadge
            }

            Rectangle().fill(Color.appDivider.opacity(0.6)).frame(height: 1)

            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar").font(SierraFont.scaled(11))
                    Text(task.dueDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.appTextSecondary)
                Spacer()
                if let eta = workOrder?.estimatedCompletionAt {
                    HStack(spacing: 5) {
                        Image(systemName: "clock").font(SierraFont.scaled(11))
                        Text("ETA \(etaInHoursMinutes(to: eta))")
                            .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Vehicle Card

    private var issueEvidenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reported Issue")
                .font(SierraFont.scaled(15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)

            Text(task.taskDescription.isEmpty ? "No issue description provided." : task.taskDescription)
                .font(SierraFont.scaled(14, weight: .semibold, design: .rounded))
                .foregroundStyle(task.taskDescription.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let reporter = reportedBy {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(SierraFont.scaled(11, weight: .semibold))
                        .foregroundStyle(Color.appOrange)
                    Text("Reported by \(reporter.displayName)")
                        .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                    Spacer()
                }
            }

            if !evidencePhotoUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(evidencePhotoUrls, id: \.self) { raw in
                            if let url = URL(string: raw) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 90, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    default:
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.appSurface)
                                            .frame(width: 90, height: 90)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundStyle(Color.appTextSecondary)
                                            )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 118, alignment: .topLeading)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    private func extractURLs(from text: String) -> [String] {
        let pattern = #"https?://[^\s]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return String(text[r])
        }
    }

    @ViewBuilder
    private var vehicleCard: some View {
        if let vehicle {
            Button { showVehicleSheet = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "car.fill")
                        .font(SierraFont.scaled(15, weight: .semibold))
                        .foregroundStyle(Color.appOrange)
                        .frame(width: 34, height: 34)
                        .background(Color.appOrange.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vehicle.licensePlate)
                            .font(SierraFont.scaled(12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.appOrange)
                        Text("\(vehicle.name) · \(vehicle.model)")
                            .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.appTextPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(SierraFont.scaled(12, weight: .bold))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(14)
                .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Assignment + Fleet Card

    private var assignmentFleetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Assigned & Working On")
                .font(SierraFont.scaled(15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)

            if let assigneeId = task.assignedToId, let staff = store.staffMember(for: assigneeId) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showAssigneeDetails.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.appOrange.opacity(0.12)).frame(width: 32, height: 32)
                            Text(staff.initials).font(SierraFont.scaled(12, weight: .bold, design: .rounded)).foregroundStyle(Color.appOrange)
                        }
                        Text(staff.displayName)
                            .font(SierraFont.scaled(14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Text("Assigned")
                            .font(SierraFont.scaled(11, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1), in: Capsule())
                    }
                }
                .buttonStyle(.plain)

                if showAssigneeDetails {
                    VStack(alignment: .leading, spacing: 6) {
                        labeledValue("Role", "Maintenance Personnel")
                        labeledValue("Status", staff.status.rawValue)
                        labeledValue("Availability", staff.availability.rawValue)
                        if let phone = staff.phone, !phone.isEmpty { labeledValue("Phone", phone) }
                    }
                    .padding(10)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))
                }
            }

            if let vehicle {
                Rectangle().fill(Color.appDivider.opacity(0.6)).frame(height: 1)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showVehicleDetails.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "car.fill")
                            .font(SierraFont.scaled(12, weight: .semibold))
                            .foregroundStyle(Color.appOrange)
                        Text(vehicle.licensePlate)
                            .font(SierraFont.scaled(12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.appOrange)
                        Text("\(vehicle.name) \(vehicle.model)")
                            .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                if showVehicleDetails {
                    VStack(alignment: .leading, spacing: 6) {
                        labeledValue("VIN", vehicle.vin)
                        labeledValue("Manufacturer", vehicle.manufacturer)
                        labeledValue("Year", "\(vehicle.year)")
                        labeledValue("Odometer", "\(Int(vehicle.odometer)) km")
                    }
                    .padding(10)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Timeline Card (Unified)

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Timeline").font(SierraFont.scaled(15, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                Spacer()
            }

            ForEach(Array(timelineStages.enumerated()), id: \.offset) { index, stage in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Image(systemName: stage.complete ? "checkmark.circle.fill" : (stage.current ? "circle.inset.filled" : "circle"))
                                .font(SierraFont.scaled(16))
                                .foregroundStyle(stage.complete ? .green : (stage.current ? Color.appOrange : Color.appDivider))
                            if index != timelineStages.count - 1 {
                                Rectangle()
                                    .fill(stage.complete ? Color.green.opacity(0.35) : Color.appDivider.opacity(0.7))
                                    .frame(width: 2, height: 20)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.label)
                                .font(SierraFont.scaled(13, weight: stage.current ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(stage.complete || stage.current ? Color.appTextPrimary : Color.appTextSecondary)
                            if let ts = timestamp(for: stage.label) {
                                Text(ts.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                    .font(SierraFont.scaled(11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        Spacer()
                    }

                    if stage.label == "In Progress", !phases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(phases) { phase in
                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        if expandedPhases.contains(phase.id) {
                                            expandedPhases.remove(phase.id)
                                        } else {
                                            expandedPhases.insert(phase.id)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: phase.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .font(SierraFont.scaled(16))
                                            .foregroundStyle(phase.isCompleted ? .green : Color.appDivider)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(phase.title)
                                                .font(SierraFont.scaled(13, weight: .semibold, design: .rounded))
                                                .foregroundStyle(Color.appTextPrimary)
                                            if let target = phase.plannedCompletionAt {
                                                Text("Target \(target.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                                                    .font(SierraFont.scaled(11, weight: .medium, design: .rounded))
                                                    .foregroundStyle(Color.appTextSecondary)
                                            } else if let mins = phase.estimatedMinutes {
                                                Text("ETA \(mins / 60)h \(mins % 60)m")
                                                    .font(SierraFont.scaled(11, weight: .medium, design: .rounded))
                                                    .foregroundStyle(Color.appTextSecondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)

                                if expandedPhases.contains(phase.id) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        labeledValue("Completion", phase.isCompleted ? "Completed" : "Pending")
                                        if let completedAt = phase.completedAt {
                                            labeledValue("Completed At", completedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                        }
                                        if let desc = phase.description, !desc.isEmpty {
                                            labeledValue("Details", desc)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(.leading, 26)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Parts Card

    private var partsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Parts Requested").font(SierraFont.scaled(15, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text("\(spareParts.count)")
                    .font(SierraFont.scaled(11, weight: .bold, design: .rounded)).foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(Color.appOrange.opacity(0.1), in: Capsule())
            }

            ForEach(Array(spareParts.enumerated()), id: \.element.id) { idx, part in
                let availableNow = availableInventoryQuantity(for: part)
                let remainingToOrder = max(0, part.quantity - max(0, part.quantityAllocated))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(part.partName).font(SierraFont.scaled(14, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                            if let pn = part.partNumber, !pn.isEmpty {
                                Text("Part #\(pn)").font(SierraFont.scaled(11, weight: .semibold, design: .monospaced)).foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        Spacer()
                        Text("×\(part.quantity)").font(SierraFont.scaled(12, weight: .bold, design: .rounded)).foregroundStyle(Color.appOrange)
                    }
                    HStack(spacing: 8) {
                        statusPill(for: part.status)
                        if availableNow > 0 {
                            Text("Inventory: \(availableNow)")
                                .font(SierraFont.scaled(11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.green.opacity(0.12), in: Capsule())
                        }
                        if remainingToOrder > 0 {
                            Text("Order: \(remainingToOrder)")
                                .font(SierraFont.scaled(11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                        }
                        Spacer()
                        if part.status == .pending {
                            Button { rejectPartTarget = part } label: {
                                Text("Reject").font(SierraFont.scaled(12, weight: .bold, design: .rounded)).foregroundStyle(.red)
                                    .padding(.horizontal, 10).padding(.vertical, 6).background(Color.red.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            Button {
                                Task { try? await store.approvePartRequestFromInventory(id: part.id, reviewedBy: currentUserId) }
                            } label: {
                                Text("Approve Inventory").font(SierraFont.scaled(12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 6).background(Color.appTextPrimary, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            if max(0, part.quantity - max(0, part.quantityAllocated)) > 0 {
                                Button {
                                    orderArrivalAt = part.expectedArrivalAt ?? Date().addingTimeInterval(48 * 3600)
                                    orderReference = part.orderReference ?? ""
                                    orderingPartTarget = part
                                } label: {
                                    Text("Place Order")
                                        .font(SierraFont.scaled(12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                        .padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if let eta = part.expectedArrivalAt, part.quantityOnOrder > 0 {
                        Text("Expected arrival \(eta.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                            .font(SierraFont.scaled(11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
                if idx < spareParts.count - 1 { Divider() }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Assignment Card

    private var assignmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Assignment").font(SierraFont.scaled(15, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)

            if let assigneeId = task.assignedToId, let staff = store.staffMember(for: assigneeId) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.appOrange.opacity(0.12)).frame(width: 32, height: 32)
                        Text(staff.initials).font(SierraFont.scaled(12, weight: .bold, design: .rounded)).foregroundStyle(Color.appOrange)
                    }
                    Text(staff.displayName).font(SierraFont.scaled(14, weight: .semibold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    Text("Assigned").font(SierraFont.scaled(11, weight: .bold, design: .rounded)).foregroundStyle(.green)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.green.opacity(0.1), in: Capsule())
                }
            } else if isApprovedAwaitingAssignment {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(SierraFont.scaled(13, weight: .semibold))
                        .foregroundStyle(Color.appOrange)
                    Text("Task approved. Assign maintenance personnel to continue.")
                        .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                }
            } else {
                Text("No technician assigned yet.")
                    .font(SierraFont.scaled(13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                if workOrder != nil {
                    Button { showWorkOrderSheet = true } label: {
                        Text("Open Full Work Order")
                            .font(SierraFont.scaled(13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(Color.appTextPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Progress Card

    private var progressCard: some View { EmptyView() }

    // MARK: - Action Card — driver dual-button pattern

    @ViewBuilder
    private var actionCard: some View {
        if task.status == .pending && !isApprovedAwaitingAssignment && task.assignedToId == nil {
            HStack(spacing: 12) {
                // Left: Reject (red outline)
                Button { showRejectSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle").font(SierraFont.scaled(13, weight: .semibold))
                        Text("Reject").font(SierraFont.scaled(14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Capsule().fill(Color.red.opacity(0.08)))
                    .overlay(Capsule().stroke(Color.red.opacity(0.22), lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                // Right: Approve
                Button { Task { await approveTask() } } label: {
                    HStack(spacing: 6) {
                        if isApproving { ProgressView().tint(.white).scaleEffect(0.8) }
                        Image(systemName: "checkmark.seal.fill").font(SierraFont.scaled(13, weight: .semibold))
                        Text("Approve").font(SierraFont.scaled(14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Color.appTextPrimary))
                }
                .buttonStyle(.plain)
                .disabled(isApproving || isRejecting)
            }
            .padding(.top, 4)
        } else if isApprovedAwaitingAssignment {
            Button { showAssignSheet = true } label: {
                HStack(spacing: 6) {
                    if isAssigning { ProgressView().tint(.white).scaleEffect(0.8) }
                    Image(systemName: "person.2.fill")
                        .font(SierraFont.scaled(13, weight: .semibold))
                    Text("Assign Maintenance Personnel")
                        .font(SierraFont.scaled(14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Capsule().fill(Color.appTextPrimary))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private var typeBadge: some View {
        let isService = task.taskType == .scheduled
        let color: Color = isService ? .blue : Color.appOrange
        let icon = isService ? "calendar.badge.checkmark" : "wrench.and.screwdriver.fill"
        return HStack(spacing: 4) {
            Image(systemName: icon).font(SierraFont.scaled(10, weight: .bold))
            Text(isService ? "Service" : "Repair").font(SierraFont.scaled(10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 5).background(color.opacity(0.12), in: Capsule())
    }

    private func statusPill(for status: SparePartsRequestStatus) -> some View {
        let tint: Color
        switch status { case .pending: tint = Color.appOrange; case .approved: tint = .green; case .rejected: tint = .red; case .fulfilled: tint = .blue }
        return Text(status.rawValue).font(SierraFont.scaled(11, weight: .bold, design: .rounded)).foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 4).background(tint.opacity(0.12), in: Capsule())
    }

    private var timelineStages: [(label: String, complete: Bool, current: Bool)] {
        let currentIndex: Int
        switch task.status {
        case .pending:
            currentIndex = task.isEffectivelyAssigned ? 1 : 0
        case .assigned:
            currentIndex = 1
        case .inProgress:
            currentIndex = 2
        case .completed:
            currentIndex = 3
        case .cancelled:
            currentIndex = 0
        }
        return ["Reported", "Assigned", "In Progress", "Completed"].enumerated().map { index, label in
            (label, index < currentIndex || task.status == .completed, index == currentIndex && task.status != .completed)
        }
    }

    private func etaInHoursMinutes(to eta: Date) -> String {
        let interval = max(0, Int(eta.timeIntervalSinceNow))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func timestamp(for stage: String) -> Date? {
        switch stage {
        case "Reported":
            return task.createdAt
        case "Assigned":
            return task.approvedAt
        case "In Progress":
            return workOrder?.startedAt
        case "Completed":
            return task.completedAt ?? workOrder?.completedAt
        default:
            return nil
        }
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(SierraFont.scaled(11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func statusColor(_ s: MaintenanceTaskStatus) -> Color {
        if s == .pending && task.isEffectivelyAssigned { return .blue }
        switch s {
        case .pending: return Color.appOrange
        case .assigned: return .blue
        case .inProgress: return .purple
        case .completed: return .green
        case .cancelled: return .gray
        }
    }
    private func availableInventoryQuantity(for part: SparePartsRequest) -> Int {
        let match = store.inventoryParts.first {
            $0.partName.caseInsensitiveCompare(part.partName) == .orderedSame
            && (($0.partNumber ?? "").caseInsensitiveCompare(part.partNumber ?? "") == .orderedSame)
        }
        return max(0, match?.currentQuantity ?? part.quantityAvailable)
    }

    private func loadData() async {
        do {
            if let wo = try await WorkOrderService.fetchWorkOrder(maintenanceTaskId: task.id) {
                fetchedWorkOrder = wo
                if store.workOrders.first(where: { $0.id == wo.id }) == nil { store.workOrders.append(wo) }
                await store.loadWorkOrderPhases(workOrderId: wo.id)
            }
        } catch {}
        loadedPhases = true
    }

    private func approveTask() async {
        guard task.status == .pending, !isApprovedAwaitingAssignment else { return }
        isApproving = true; defer { isApproving = false }
        do {
            try await MaintenanceTaskService.approveTaskWithoutAssignment(
                taskId: task.id,
                approvedById: currentUserId
            )
            let sourceTripId = task.sourceInspectionId.flatMap { inspectionId in
                store.vehicleInspections.first(where: { $0.id == inspectionId })?.tripId
            }
            await MaintenanceTaskService.resolveLinkedDefectAlertsOnApproval(
                task: task,
                tripId: sourceTripId
            )
            onUpdate()
            showAssignSheet = true
        } catch {
            errorMessage = "Failed to approve task: \(error.localizedDescription)"; showError = true
        }
    }

    private func assignApprovedTask(to assigneeId: UUID) async {
        isAssigning = true
        defer { isAssigning = false }
        do {
            try await store.assignApprovedMaintenanceTaskAndEnsureWorkOrder(
                taskId: task.id,
                assignedToId: assigneeId
            )
            try? await NotificationService.insertNotification(
                recipientId: assigneeId,
                type: .general,
                title: "New Maintenance Task",
                body: "You were assigned: \(task.title)",
                entityType: "maintenance_task",
                entityId: task.id
            )
            onUpdate()
            dismiss()
        } catch {
            errorMessage = "Failed to assign task: \(error.localizedDescription)"
            showError = true
        }
    }

    private var rejectSheet: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("Provide a rejection reason").font(SierraFont.scaled(14, weight: .semibold, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14).fill(Color.appCardBg).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appDivider, lineWidth: 1)).frame(minHeight: 110)
                    if rejectionReason.isEmpty { Text("Reason for rejection…").font(SierraFont.scaled(14, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary.opacity(0.5)).padding(14) }
                    TextEditor(text: $rejectionReason).frame(minHeight: 110).padding(10).background(Color.clear)
                }
                .padding(.horizontal, 16)
                Button { Task { await rejectTask() } } label: {
                    HStack(spacing: 8) {
                        if isRejecting { ProgressView().tint(.white) }
                        Text("Confirm Rejection").font(SierraFont.scaled(14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(rejectionReason.isEmpty ? Color.gray : Color.red, in: Capsule())
                }
                .buttonStyle(.plain).disabled(rejectionReason.isEmpty || isRejecting).padding(.horizontal, 16)
                Spacer()
            }
            .padding(.top, 18)
            .background(Color.appSurface.ignoresSafeArea())
            .navigationTitle("Reject Task").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showRejectSheet = false }.foregroundStyle(Color.appOrange) } }
        }
        .presentationDetents([.medium])
    }

    private func rejectTask() async {
        guard task.status == .pending || task.isEffectivelyAssigned else { return }
        isRejecting = true; defer { isRejecting = false }
        do {
            try await MaintenanceTaskService.rejectTask(taskId: task.id, approvedById: currentUserId, reason: rejectionReason)
            let sourceTripId = task.sourceInspectionId.flatMap { inspectionId in
                store.vehicleInspections.first(where: { $0.id == inspectionId })?.tripId
            }
            await MaintenanceTaskService.resolveLinkedDefectAlertsOnTerminalDecision(
                task: task,
                tripId: sourceTripId
            )
            showRejectSheet = false; onUpdate(); dismiss()
        } catch {
            errorMessage = "Failed to reject task: \(error.localizedDescription)"; showError = true
        }
    }

    private func orderLabeledValue(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(SierraFont.scaled(12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(1)
        }
    }
}

private struct AssignTechnicianScreen: View {
    let candidates: [StaffMember]
    let onAssign: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if candidates.isEmpty {
                Text("No free maintenance personnel available right now.")
                    .font(SierraFont.scaled(14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.top, 6)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(candidates) { staff in
                            Button {
                                onAssign(staff.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle().fill(Color.appOrange.opacity(0.12)).frame(width: 34, height: 34)
                                        Text(staff.initials)
                                            .font(SierraFont.scaled(12, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.appOrange)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(staff.displayName)
                                            .font(SierraFont.scaled(14, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.appTextPrimary)
                                        Text(staff.availability.rawValue)
                                            .font(SierraFont.scaled(11, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color.appTextSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(SierraFont.scaled(11, weight: .bold))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appDivider.opacity(0.45), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Assign Personnel")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reject Part Reason Sheet

private struct RejectPartReasonSheet: View {
    let part: SparePartsRequest
    let onConfirm: (String) -> Void

    @State private var reason = ""
    @Environment(\.dismiss) private var dismiss
    private var trimmed: String { reason.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Add rejection reason for \(part.partName).")
                    .font(SierraFont.scaled(14, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14).fill(Color.appCardBg).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appDivider, lineWidth: 1)).frame(minHeight: 120)
                    if reason.isEmpty { Text("Reason…").font(SierraFont.scaled(14, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary.opacity(0.5)).padding(14) }
                    TextEditor(text: $reason).frame(minHeight: 120).padding(10).background(Color.clear)
                }
                Button { onConfirm(trimmed); dismiss() } label: {
                    Text("Reject Part").font(SierraFont.scaled(14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(trimmed.isEmpty ? Color.gray : Color.red, in: Capsule())
                }
                .disabled(trimmed.isEmpty)
                Spacer()
            }
            .padding(16)
            .background(Color.appSurface.ignoresSafeArea())
            .navigationTitle("Reject Part").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Color.appOrange) } }
        }
    }
}
