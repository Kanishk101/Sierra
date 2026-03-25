import SwiftUI

// MARK: - MaintenanceTaskDetailView

struct MaintenanceTaskDetailView: View {
    let task: MaintenanceTask
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showPartsRequestSheet = false
    @State private var showEstimatedTimeSheet = false
    @State private var estimatedDays: Int = 0
    @State private var estimatedHours: Int = 1
    @State private var estimatedMinutes: Int = 0
    @State private var isStarting = false
    @State private var isCompleting = false
    @State private var etaDate: Date = Date()
    @State private var phasesLoaded = false
    @State private var showVehicleSheet = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }
    private var workOrder: WorkOrder? { store.workOrder(forMaintenanceTask: task.id) }
    private var vehicle: Vehicle? { store.vehicle(for: task.vehicleId) }
    private var sprs: [SparePartsRequest] { store.sparePartsRequests(forTask: task.id) }
    private var phases: [WorkOrderPhase] { store.phases(forWorkOrder: workOrder?.id ?? UUID()) }
    private var allPhasesDone: Bool {
        !phases.isEmpty && phases.allSatisfy { $0.isCompleted }
    }
    private var assignedBy: String {
        store.staffMember(for: task.createdByAdminId)?.name ?? "Admin"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Overview Section
                overviewCard
                // 2. Progress Section (phases — only when in progress)
                if task.status == .inProgress { progressCard }
                // 3. Parts Section
                if !sprs.isEmpty || task.status == .assigned { partsCard }
                // Actions
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Task Overview")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPartsRequestSheet) {
            SparePartsRequestSheet(task: task)
                .environment(store)
        }
        .sheet(isPresented: $showVehicleSheet) {
            if let vehicle {
                VehicleQuickStatusSheet(vehicle: vehicle)
                    .environment(store)
            }
        }
        .sheet(isPresented: $showEstimatedTimeSheet) {
            estimatedTimeSheet
        }
        .task {
            if let wo = workOrder {
                if let eta = wo.estimatedCompletionAt { etaDate = eta }
                await store.loadWorkOrderPhases(workOrderId: wo.id)
                phasesLoaded = true
            }
        }
    }

    // MARK: - 1. Overview Card (Task + Vehicle + Status combined)

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status banner at top
            HStack(spacing: 10) {
                Image(systemName: statusBannerIcon(task.status))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(taskStatusColor(task.status))
                Text(statusBannerText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(taskStatusColor(task.status))
                Spacer()
                if task.status == .inProgress, !dueCountdown.isEmpty {
                    Text(dueCountdown)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(taskStatusColor(task.status))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(taskStatusColor(task.status).opacity(0.1), in: Capsule())
                }
            }
            .padding(16)
            .background(taskStatusColor(task.status).opacity(0.06))

            Divider()

            // Task info
            VStack(alignment: .leading, spacing: 12) {
                // Title + priority
                HStack(alignment: .top) {
                    Text(task.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    priorityBadge(task.priority)
                }

                // Description
                Text(task.taskDescription)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                // Info rows
                infoRow(icon: "person.fill", label: "Assigned by", value: assignedBy)
                infoRow(icon: "calendar", label: "Due", value: task.dueDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                if let wo = workOrder {
                    infoRow(icon: "tag.fill", label: "Type", value: wo.workOrderType.rawValue.capitalized)
                }

                // Vehicle sub-section
                if let v = vehicle {
                    Divider()
                    Button {
                        showVehicleSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appOrange.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "car.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.appOrange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.name)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.appTextPrimary)
                                Text("\(v.licensePlate) · \(v.model)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            Spacer()
                            Text("\(Int(v.odometer)) km")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appTextSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                // ETA editor
                if task.status == .inProgress, let wo = workOrder, wo.estimatedCompletionAt != nil {
                    Divider()
                    HStack {
                        Label("ETA", systemImage: "clock.badge")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                    }
                    DatePicker(
                        "ETA",
                        selection: $etaDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .tint(Color.appOrange)
                    .labelsHidden()
                    .onChange(of: etaDate) { _, newDate in
                        guard let woId = workOrder?.id else { return }
                        Task {
                            try? await WorkOrderService.updateEstimatedCompletion(workOrderId: woId, date: newDate)
                            if let idx = store.workOrders.firstIndex(where: { $0.id == woId }) {
                                store.workOrders[idx].estimatedCompletionAt = newDate
                            }
                        }
                    }
                }
            }
            .padding(18)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.appDivider, lineWidth: 1)
        )
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.appOrange)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
        }
    }

    // MARK: - 2. Progress Card (Phases)

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Progress")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                let done = phases.filter { $0.isCompleted }.count
                Text("\(done)/\(phases.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(allPhasesDone ? .green : Color.appOrange)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((allPhasesDone ? Color.green : Color.appOrange).opacity(0.1), in: Capsule())
            }
            .padding(18)

            if !phasesLoaded {
                HStack { Spacer(); ProgressView().tint(Color.appOrange); Spacer() }
                    .padding(18)
            } else if phases.isEmpty {
                Text("No phases defined")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            } else {
                ForEach(Array(phases.enumerated()), id: \.element.id) { idx, phase in
                    phaseRow(phase)
                    if idx < phases.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.appDivider, lineWidth: 1)
        )
    }

    private func phaseRow(_ phase: WorkOrderPhase) -> some View {
        HStack(spacing: 12) {
            Button {
                guard !phase.isCompleted else { return }
                Task {
                    try? await store.completePhase(phase)
                    if let wo = workOrder {
                        await store.loadWorkOrderPhases(workOrderId: wo.id)
                    }
                }
            } label: {
                Image(systemName: phase.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(phase.isCompleted ? .green : Color.appDivider)
            }
            .buttonStyle(.plain)
            .disabled(phase.isCompleted)

            VStack(alignment: .leading, spacing: 3) {
                Text(phase.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(phase.isCompleted ? Color.appTextSecondary : Color.appTextPrimary)
                    .strikethrough(phase.isCompleted)
                if let desc = phase.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                }
                if phase.isCompleted, let completedAt = phase.completedAt {
                    Text("Done \(completedAt.formatted(.dateTime.hour().minute()))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.green)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - 3. Parts Card

    private var partsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Parts")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                if let wo = workOrder, wo.partsSubStatus != .none {
                    Label(wo.partsSubStatus.displayText, systemImage: wo.partsSubStatus.icon)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(partsStatusColor(wo.partsSubStatus))
                }
            }
            .padding(18)

            if sprs.isEmpty {
                Text("No parts requested yet")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            } else {
                ForEach(Array(sprs.enumerated()), id: \.element.id) { idx, spr in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(sprStatusColor(spr.status))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(spr.partName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.appTextPrimary)
                            if let pn = spr.partNumber, !pn.isEmpty {
                                Text(pn)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        Spacer()
                        Text("×\(spr.quantity)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appTextPrimary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    if idx < sprs.count - 1 {
                        Divider().padding(.leading, 38)
                    }
                }

                // Summary row
                Divider()
                HStack {
                    let pending = sprs.filter { $0.status == .pending }.count
                    let approved = sprs.filter { $0.status == .approved }.count
                    let fulfilled = sprs.filter { $0.status == .fulfilled }.count
                    Text("\(sprs.count) item\(sprs.count == 1 ? "" : "s") · \(pending) pending · \(approved) approved · \(fulfilled) fulfilled")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(18)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.appDivider, lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        let status = task.status
        VStack(spacing: 10) {
            if status == .assigned || status == .inProgress {
                actionButton(
                    title: sprs.isEmpty ? "Request Parts" : "Request More Parts",
                    icon: "shippingbox.fill",
                    color: Color.appOrange
                ) { showPartsRequestSheet = true }
            }

            if status == .assigned,
               let wo = workOrder,
               (wo.partsSubStatus == .ready || wo.partsSubStatus == .approved || wo.partsSubStatus == .none) {
                actionButton(
                    title: "Start Work",
                    icon: "play.fill",
                    color: .purple
                ) { showEstimatedTimeSheet = true }
            }

            if status == .inProgress {
                Button {
                    Task { await markRepairDone() }
                } label: {
                    HStack(spacing: 8) {
                        if isCompleting { ProgressView().tint(.white) }
                        Image(systemName: "checkmark.seal.fill")
                        Text(allPhasesDone ? "Complete" : "Complete All Phases First")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(
                        allPhasesDone ? Color.green : Color.green.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
                .disabled(isCompleting || !allPhasesDone)

                if !phases.isEmpty && !allPhasesDone {
                    let completedCount = phases.filter { $0.isCompleted }.count
                    Text("\(completedCount)/\(phases.count) phases completed")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(color, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Estimated Time Sheet

    private var estimatedTimeSheet: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.appOrange.opacity(0.1))
                                .frame(width: 64, height: 64)
                            Image(systemName: "timer")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(Color.appOrange)
                        }
                        Text("Set Estimated Time")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appTextPrimary)
                        Text("How long will this repair take?")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("Days").font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appTextSecondary)
                                .frame(maxWidth: .infinity)
                            Text("Hours").font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appTextSecondary)
                                .frame(maxWidth: .infinity)
                            Text("Minutes").font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appTextSecondary)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)

                        HStack(spacing: 0) {
                            Picker("Days", selection: $estimatedDays) {
                                ForEach(0..<31, id: \.self) { d in
                                    Text(d == 0 ? "–" : "\(d)d").tag(d)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Hours", selection: $estimatedHours) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(h == 0 ? "–" : "\(h)h").tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Minutes", selection: $estimatedMinutes) {
                                ForEach(Array(stride(from: 0, through: 60, by: 5)), id: \.self) { m in
                                    Text(m == 0 ? "0m" : "\(m)m").tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                        .tint(Color.appOrange)
                        .frame(height: 160)
                        .padding(.horizontal, 8)
                    }
                    .padding(.vertical, 12)
                    .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appDivider, lineWidth: 1))
                    .padding(.horizontal, 20)

                    let totalMins = estimatedDays * 1440 + estimatedHours * 60 + estimatedMinutes
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill").font(.system(size: 12)).foregroundStyle(Color.appOrange)
                        if totalMins == 0 {
                            Text("Select a duration")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.appTextSecondary)
                        } else {
                            Text("ETA: \(etaSummary(days: estimatedDays, hours: estimatedHours, mins: estimatedMinutes))")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appTextPrimary)
                        }
                    }
                    .padding(.top, 14)

                    Spacer()

                    Button {
                        Task { await startWork() }
                    } label: {
                        HStack(spacing: 8) {
                            if isStarting { ProgressView().tint(.white).scaleEffect(0.85) }
                            Image(systemName: "play.fill")
                            Text("Start Work Now")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(
                            totalMins == 0 ? Color.appTextSecondary.opacity(0.35) : Color.purple,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .disabled(isStarting || totalMins == 0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Set ETA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEstimatedTimeSheet = false }
                        .foregroundStyle(Color.appOrange)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Backend Actions

    private func startWork() async {
        isStarting = true
        defer { isStarting = false }

        let totalMins = estimatedDays * 1440 + estimatedHours * 60 + estimatedMinutes
        let eta = Date().addingTimeInterval(Double(totalMins * 60))

        if var wo = workOrder {
            wo.estimatedCompletionAt = eta
            wo.startedAt = Date()
            wo.status = .inProgress
            try? await store.updateWorkOrder(wo)
        }

        if let idx = store.maintenanceTasks.firstIndex(where: { $0.id == task.id }) {
            store.maintenanceTasks[idx].status = .inProgress
            try? await MaintenanceTaskService.updateMaintenanceTask(store.maintenanceTasks[idx])
        }

        showEstimatedTimeSheet = false
    }

    private func markRepairDone() async {
        isCompleting = true
        defer { isCompleting = false }
        try? await store.closeWorkOrder(id: workOrder?.id ?? UUID())
    }

    // MARK: - Badge & Helper Views

    private func priorityBadge(_ p: TaskPriority) -> some View {
        let color = priorityColor(p)
        return HStack(spacing: 4) {
            Image(systemName: priorityIcon(p)).font(.system(size: 10))
            Text(p.rawValue).font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.1), in: Capsule())
    }

    // MARK: - Helpers

    private var dueCountdown: String {
        guard task.status == .inProgress,
              let wo = workOrder,
              let eta = wo.estimatedCompletionAt else { return "" }
        let remaining = eta.timeIntervalSince(Date())
        if remaining <= 0 { return "Overdue" }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m left" : "\(m)m left"
    }

    private var statusBannerText: String {
        if task.status == .assigned, let wo = workOrder, wo.partsSubStatus != .none {
            return wo.partsSubStatus.displayText
        }
        return task.status.rawValue
    }

    private func taskStatusColor(_ status: MaintenanceTaskStatus) -> Color {
        switch status {
        case .pending:    return .gray
        case .assigned:   return .blue
        case .inProgress: return .purple
        case .completed:  return .green
        case .cancelled:  return .red
        }
    }

    private func statusBannerIcon(_ status: MaintenanceTaskStatus) -> String {
        switch status {
        case .pending:    return "clock"
        case .assigned:   return "person.badge.clock"
        case .inProgress: return "wrench.and.screwdriver"
        case .completed:  return "checkmark.seal.fill"
        case .cancelled:  return "xmark.circle"
        }
    }

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .low: return .green; case .medium: return .blue
        case .high: return .orange; case .urgent: return .red
        }
    }

    private func priorityIcon(_ p: TaskPriority) -> String {
        switch p {
        case .low: return "arrow.down"; case .medium: return "minus"
        case .high: return "arrow.up"; case .urgent: return "exclamationmark.2"
        }
    }

    private func partsStatusColor(_ status: PartsSubStatus) -> Color {
        switch status {
        case .none:           return .gray
        case .requested:      return .orange
        case .partiallyReady: return .orange
        case .approved:       return Color(red: 0.1, green: 0.7, blue: 0.4)
        case .orderPlaced:    return .orange
        case .ready:          return .green
        }
    }

    private func sprStatusColor(_ status: SparePartsRequestStatus) -> Color {
        switch status {
        case .pending:   return .orange
        case .approved:  return .blue
        case .rejected:  return .red
        case .fulfilled: return .green
        }
    }

    private func etaSummary(days: Int, hours: Int, mins: Int) -> String {
        var parts: [String] = []
        if days > 0  { parts.append("\(days) day\(days == 1 ? "" : "s")") }
        if hours > 0 { parts.append("\(hours) hr\(hours == 1 ? "" : "s")") }
        if mins > 0  { parts.append("\(mins) min") }
        return parts.isEmpty ? "–" : parts.joined(separator: " ")
    }
}
