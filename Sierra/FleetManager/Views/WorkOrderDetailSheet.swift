import SwiftUI

// MARK: - WorkOrderDetailSheet (Admin — read-only + parts approval)

struct WorkOrderDetailSheet: View {
    let task: MaintenanceTask
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var loadedPhases = false
    @State private var rejectingPartId: UUID?
    @State private var rejectReason = ""
    @State private var showStaffSheet = false
    @State private var orderingPartTarget: SparePartsRequest?
    @State private var orderArrivalAt: Date = Date().addingTimeInterval(48 * 3600)
    @State private var orderReference: String = ""

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }
    private var workOrder: WorkOrder? { store.workOrder(forMaintenanceTask: task.id) }
    private var vehicle: Vehicle? { store.vehicle(for: task.vehicleId) }
    private var assignedStaff: StaffMember? {
        guard let wo = workOrder else { return nil }
        return store.staffMember(for: wo.assignedToId)
    }
    private var maintenanceProfile: MaintenanceProfile? {
        guard let staff = assignedStaff else { return nil }
        return store.maintenanceProfile(for: staff.id)
    }
    private var phases: [WorkOrderPhase] {
        guard let wo = workOrder else { return [] }
        return store.phases(forWorkOrder: wo.id)
    }
    private var parts: [SparePartsRequest] {
        store.sparePartsRequests(forTask: task.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    headerSection
                    if let wo = workOrder {
                        statusTimeline(wo)
                        phasesSection
                        partsSection
                        costsSection(wo)
                        etaSection(wo)
                        technicianSection
                    } else {
                        noWorkOrderState
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Work Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appOrange)
                }
            }
            .sheet(isPresented: $showStaffSheet) {
                if let staff = assignedStaff {
                    StaffDetailSheet(member: staff)
                        .environment(store)
                }
            }
            .sheet(item: $orderingPartTarget) { part in
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Place order for \(part.partName)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
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
                            }
                        } label: {
                            Text("Confirm Place Order")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
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
                .presentationDetents([.medium])
            }
            .task {
                if let wo = workOrder {
                    await store.loadWorkOrderPhases(workOrderId: wo.id)
                    loadedPhases = true
                }
            }
        }
    }

    // MARK: - 1. Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Vehicle
            if let v = vehicle {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.appOrange.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "car.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.appOrange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.name)
                            .font(.headline)
                        Text(v.licensePlate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }

            // Task title + badges
            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.title3.weight(.bold))
                HStack(spacing: 8) {
                    priorityBadge
                    typeBadge
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var priorityBadge: some View {
        let color = priorityColor(task.priority)
        return Text(task.priority.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var typeBadge: some View {
        let isService = task.taskType == .scheduled
        let color: Color = isService ? .blue : .orange
        let icon = isService ? "calendar.badge.checkmark" : "wrench.and.screwdriver.fill"
        let label = isService ? "Service" : "Repair"
        return HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(label).font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - 2. Status Timeline

    private func statusTimeline(_ wo: WorkOrder) -> some View {
        let stages = buildTimelineStages(wo)
        return VStack(alignment: .leading, spacing: 0) {
            sectionLabel("STATUS TIMELINE", icon: "clock.arrow.circlepath")
            ForEach(Array(stages.enumerated()), id: \.offset) { idx, stage in
                timelineRow(stage: stage, isLast: idx == stages.count - 1)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private func timelineRow(stage: TimelineStage, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: stage.isComplete ? "checkmark.circle.fill" : stage.isCurrent ? "circle.inset.filled" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(stage.isComplete ? .green : stage.isCurrent ? Color.appOrange : Color(.systemGray3))
                if !isLast {
                    Rectangle()
                        .fill(stage.isComplete ? Color.green.opacity(0.3) : Color(.systemGray4))
                        .frame(width: 2, height: 32)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(stage.label)
                    .font(.subheadline.weight(stage.isCurrent ? .bold : .medium))
                    .foregroundStyle(stage.isComplete || stage.isCurrent ? .primary : .secondary)
                if let ts = stage.timestamp {
                    Text(ts.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - 3. Phases

    private var phasesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("PHASES", icon: "list.bullet.clipboard")
                Spacer()
                if !phases.isEmpty {
                    let done = phases.filter { $0.isCompleted }.count
                    Text("\(done)/\(phases.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(done == phases.count ? .green : Color.appOrange)
                }
            }

            if !loadedPhases {
                HStack { Spacer(); ProgressView().tint(Color.appOrange); Spacer() }
                    .padding(.vertical, 8)
            } else if phases.isEmpty {
                emptyLabel("No phases defined")
            } else {
                ForEach(phases) { phase in
                    phaseRow(phase)
                    if phase.id != phases.last?.id { Divider() }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private func phaseRow(_ phase: WorkOrderPhase) -> some View {
        HStack(spacing: 10) {
            Image(systemName: phase.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(phase.isCompleted ? .green : Color(.systemGray3))
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Phase \(phase.phaseNumber)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.appOrange)
                    Text(phase.title)
                        .font(.subheadline.weight(.medium))
                        .strikethrough(phase.isCompleted)
                        .foregroundStyle(phase.isCompleted ? .secondary : .primary)
                }
                if let desc = phase.description, !desc.isEmpty {
                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                if let target = phase.plannedCompletionAt {
                    Text("Target \(target.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appOrange)
                }
                if phase.isCompleted, let at = phase.completedAt {
                    Text("Completed \(at.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                        .font(.system(size: 10)).foregroundStyle(.green)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - 4. Parts

    private var partsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SPARE PARTS", icon: "shippingbox.fill")

            if parts.isEmpty {
                emptyLabel("No parts requested")
            } else {
                ForEach(parts) { part in
                    partRow(part)
                    if part.id != parts.last?.id { Divider() }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private func partRow(_ part: SparePartsRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(part.partName)
                        .font(.subheadline.weight(.semibold))
                    if let pn = part.partNumber, !pn.isEmpty {
                        Text("# \(pn)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                partStatusBadge(part.status)
            }

            HStack(spacing: 16) {
                Label("Qty: \(part.quantity)", systemImage: "number")
                    .font(.caption).foregroundStyle(.secondary)
                Label("Inventory: \(availableInventoryQuantity(for: part))", systemImage: "shippingbox")
                    .font(.caption).foregroundStyle(.green)
                if let cost = part.estimatedUnitCost {
                    Label("₹\(cost, specifier: "%.0f")/unit", systemImage: "indianrupeesign.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            // Approve / Reject actions for pending parts
            if part.status == .pending {
                if rejectingPartId == part.id {
                    rejectReasonInput(part)
                } else {
                    partActionButtons(part)
                }
            }

            if let reason = part.rejectionReason, part.status == .rejected {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill").font(.caption2)
                    Text("Rejected: \(reason)")
                        .font(.caption)
                }
                .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private func partActionButtons(_ part: SparePartsRequest) -> some View {
        let remainingToOrder = max(0, part.quantity - max(0, part.quantityAllocated))
        return HStack(spacing: 10) {
            Button {
                Task { try? await store.approvePartRequestFromInventory(id: part.id, reviewedBy: currentUserId) }
            } label: {
                Label("Approve Inventory", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.green, in: Capsule())
            }
            .buttonStyle(.plain)

            if remainingToOrder > 0 {
                Button {
                    orderArrivalAt = part.expectedArrivalAt ?? Date().addingTimeInterval(48 * 3600)
                    orderReference = part.orderReference ?? ""
                    orderingPartTarget = part
                } label: {
                    Label("Place Order", systemImage: "cart.badge.plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation { rejectingPartId = part.id; rejectReason = "" }
            } label: {
                Label("Reject", systemImage: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.red, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func rejectReasonInput(_ part: SparePartsRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Reason for rejection…", text: $rejectReason)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            HStack(spacing: 8) {
                Button("Cancel") {
                    withAnimation { rejectingPartId = nil }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                Button("Confirm Reject") {
                    Task { await rejectPart(part) }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.red, in: Capsule())
                .disabled(rejectReason.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func partStatusBadge(_ status: SparePartsRequestStatus) -> some View {
        let color = partStatusColor(status)
        return Text(status.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - 5. Costs

    private func costsSection(_ wo: WorkOrder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("COSTS", icon: "indianrupeesign.circle")
            HStack(spacing: 0) {
                costCell("Labour", value: wo.labourCostTotal, color: .blue)
                costCell("Parts", value: wo.partsCostTotal, color: .orange)
                costCell("Total", value: wo.totalCost, color: .green)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private func costCell(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("₹\(value, specifier: "%.0f")")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - 6. ETA

    private func etaSection(_ wo: WorkOrder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("ESTIMATED COMPLETION", icon: "clock.badge")
            if let eta = wo.estimatedCompletionAt {
                let remaining = eta.timeIntervalSince(Date())
                let overdue = remaining <= 0
                HStack(spacing: 8) {
                    Image(systemName: overdue ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                        .foregroundStyle(overdue ? .red : .purple)
                    Text(eta.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if overdue {
                        Text("OVERDUE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.red.opacity(0.1), in: Capsule())
                    } else {
                        let h = Int(remaining) / 3600
                        Text("\(h)h remaining")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.purple)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "clock").foregroundStyle(.secondary)
                    Text("ETA not set by technician")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    // MARK: - 7. Technician

    private var technicianSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ASSIGNED TECHNICIAN", icon: "person.fill.wrench")

            if let staff = assignedStaff {
                Button {
                    showStaffSheet = true
                } label: {
                    technicianCard(staff)
                }
                .buttonStyle(.plain)
            } else {
                emptyLabel("No technician assigned")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private func technicianCard(_ staff: StaffMember) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(staff.initials)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(staff.displayName)
                    .font(.subheadline.weight(.semibold))
                if let profile = maintenanceProfile {
                    if !profile.specializations.isEmpty {
                        Text(profile.specializations.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text("\(profile.yearsOfExperience) yrs exp • \(profile.totalTasksCompleted) tasks done")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let phone = staff.phone {
                    Label(phone, systemImage: "phone.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.appOrange)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Empty / No Work Order

    private var noWorkOrderState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color(.systemGray3))
            Text("No Work Order")
                .font(.headline)
            Text("A work order will be created when this task is assigned to a technician.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .kerning(0.8)
    }

    private func emptyLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color(.systemGray3))
            .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func rejectPart(_ part: SparePartsRequest) async {
        let reason = rejectReason.trimmingCharacters(in: .whitespaces)
        try? await store.rejectSparePartsRequest(id: part.id, reviewedBy: currentUserId, reason: reason)
        withAnimation { rejectingPartId = nil }
    }

    // MARK: - Timeline Builder

    private struct TimelineStage {
        let label: String
        let isComplete: Bool
        let isCurrent: Bool
        let timestamp: Date?
    }

    private func buildTimelineStages(_ wo: WorkOrder) -> [TimelineStage] {
        let statusOrder: [WorkOrderStatus] = [.open, .inProgress, .onHold, .completed, .closed]
        let currentIdx = statusOrder.firstIndex(of: wo.status) ?? 0

        var stages: [TimelineStage] = []
        // Open
        stages.append(TimelineStage(label: "Open", isComplete: currentIdx > 0, isCurrent: currentIdx == 0, timestamp: wo.createdAt))
        // In Progress
        stages.append(TimelineStage(label: "In Progress", isComplete: currentIdx > 1, isCurrent: currentIdx == 1, timestamp: wo.startedAt))
        // On Hold — only show if current or past
        if wo.status == .onHold || currentIdx > 2 {
            stages.append(TimelineStage(label: "On Hold", isComplete: currentIdx > 2, isCurrent: currentIdx == 2, timestamp: nil))
        }
        // Completed
        stages.append(TimelineStage(label: "Completed", isComplete: currentIdx >= 3, isCurrent: currentIdx == 3, timestamp: wo.completedAt))
        // Closed
        if wo.status == .closed {
            stages.append(TimelineStage(label: "Closed", isComplete: true, isCurrent: currentIdx == 4, timestamp: wo.completedAt))
        }
        return stages
    }

    // MARK: - Color Helpers

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    private func partStatusColor(_ s: SparePartsRequestStatus) -> Color {
        switch s {
        case .pending:   return .orange
        case .approved:  return .green
        case .rejected:  return .red
        case .fulfilled: return .blue
        }
    }

    private func availableInventoryQuantity(for part: SparePartsRequest) -> Int {
        let match = store.inventoryParts.first {
            $0.partName.caseInsensitiveCompare(part.partName) == .orderedSame
            && (($0.partNumber ?? "").caseInsensitiveCompare(part.partNumber ?? "") == .orderedSame)
        }
        return max(0, match?.currentQuantity ?? part.quantityAvailable)
    }
}
