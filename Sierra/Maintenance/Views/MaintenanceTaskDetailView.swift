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
    @State private var phasesLoaded = false
    @State private var showVehicleSheet = false
    @State private var showPhasePlanner = false
    @State private var phasePlanDrafts: [PhasePlanDraft] = []

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }
    private var workOrder: WorkOrder? { store.workOrder(forMaintenanceTask: task.id) }
    private var vehicle: Vehicle? { store.vehicle(for: task.vehicleId) }
    private var sprs: [SparePartsRequest] { store.sparePartsRequests(forTask: task.id) }
    private var phases: [WorkOrderPhase] { store.phases(forWorkOrder: workOrder?.id ?? UUID()) }
    private var allPhasesDone: Bool { !phases.isEmpty && phases.allSatisfy { $0.isCompleted } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overviewCard
                if task.status == .inProgress { progressCard }
                if !sprs.isEmpty || task.status == .assigned { partsCard }
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
            SparePartsRequestSheet(task: task).environment(store)
        }
        .sheet(isPresented: $showVehicleSheet) {
            if let vehicle { VehicleQuickStatusSheet(vehicle: vehicle).environment(store) }
        }
        .sheet(isPresented: $showEstimatedTimeSheet) { estimatedTimeSheet }
        .sheet(isPresented: $showPhasePlanner) { phasePlannerSheet }
        .task {
            if let wo = workOrder {
                await store.loadWorkOrderPhases(workOrderId: wo.id)
                phasesLoaded = true
            }
        }
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status banner
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

            VStack(alignment: .leading, spacing: 12) {
                // Title + priority (NO description shown in overview)
                HStack(alignment: .top) {
                    Text(task.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    priorityBadge(task.priority)
                }

                Divider()

                infoRow(icon: "calendar", label: "Due", value: task.dueDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                if let wo = workOrder {
                    infoRow(icon: "tag.fill", label: "Type", value: wo.workOrderType.rawValue.capitalized)
                }

                if let v = vehicle {
                    Divider()
                    Button { showVehicleSheet = true } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.appOrange.opacity(0.1)).frame(width: 44, height: 44)
                                Image(systemName: "car.fill").font(.system(size: 18)).foregroundStyle(Color.appOrange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.name).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                                Text("\(v.licensePlate) · \(v.model)").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                            }
                            Spacer()
                            Text("\(Int(v.odometer)) km").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if let wo = workOrder, let eta = wo.estimatedCompletionAt {
                    Divider()
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge").font(.system(size: 12)).foregroundStyle(Color.appOrange).frame(width: 20)
                        Text("ETA").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text(eta.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                    }
                    Text("ETA is locked after work starts")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .padding(18)
        }
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.appCardBg).shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appDivider, lineWidth: 1))
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Color.appOrange).frame(width: 20)
            Text(label).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Progress").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                Spacer()
                if task.status == .inProgress {
                    Button { showPhasePlanner = true } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.appOrange)
                    }
                    .buttonStyle(.plain)
                }
                let done = phases.filter { $0.isCompleted }.count
                Text("\(done)/\(phases.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(allPhasesDone ? .green : Color.appOrange)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((allPhasesDone ? Color.green : Color.appOrange).opacity(0.1), in: Capsule())
            }
            .padding(18)

            if !phasesLoaded {
                HStack { Spacer(); ProgressView().tint(Color.appOrange); Spacer() }.padding(18)
            } else if phases.isEmpty {
                Text("No phases defined").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary).padding(.horizontal, 18).padding(.bottom, 18)
            } else {
                ForEach(Array(phases.enumerated()), id: \.element.id) { idx, phase in
                    phaseRow(phase)
                    if idx < phases.count - 1 { Divider().padding(.leading, 56) }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.appCardBg).shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appDivider, lineWidth: 1))
    }

    private func phaseRow(_ phase: WorkOrderPhase) -> some View {
        HStack(spacing: 12) {
            Button {
                guard !phase.isCompleted else { return }
                Task {
                    try? await store.completePhase(phase)
                    if let wo = workOrder { await store.loadWorkOrderPhases(workOrderId: wo.id) }
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
                    Text(desc).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary).lineLimit(2)
                }
                if let mins = phase.estimatedMinutes, mins > 0 {
                    Text("ETA \(mins / 60)h \(mins % 60)m").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(Color.appOrange)
                }
                if phase.isCompleted, let completedAt = phase.completedAt {
                    Text("Done \(completedAt.formatted(.dateTime.hour().minute()))").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.green)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }

    // MARK: - Parts Card

    private var partsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Parts").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                Spacer()
                if let wo = workOrder, wo.partsSubStatus != .none {
                    Label(wo.partsSubStatus.displayText, systemImage: wo.partsSubStatus.icon)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(partsStatusColor(wo.partsSubStatus))
                }
            }
            .padding(18)

            if sprs.isEmpty {
                Text("No parts requested yet").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary).padding(.horizontal, 18).padding(.bottom, 18)
            } else {
                ForEach(Array(sprs.enumerated()), id: \.element.id) { idx, spr in
                    HStack(spacing: 12) {
                        Circle().fill(sprStatusColor(spr.status)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(spr.partName).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                            if let pn = spr.partNumber, !pn.isEmpty {
                                Text(pn).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        Spacer()
                        Text("×\(spr.quantity)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    if idx < sprs.count - 1 { Divider().padding(.leading, 38) }
                }
                Divider()
                HStack {
                    let pending = sprs.filter { $0.status == .pending }.count
                    let approved = sprs.filter { $0.status == .approved }.count
                    let fulfilled = sprs.filter { $0.status == .fulfilled }.count
                    Text("\(sprs.count) item\(sprs.count == 1 ? "" : "s") · \(pending) pending · \(approved) approved · \(fulfilled) fulfilled")
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                }
                .padding(18)
            }
        }
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.appCardBg).shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appDivider, lineWidth: 1))
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        let status = task.status
        VStack(spacing: 10) {
            if status == .assigned || status == .inProgress {
                actionButton(title: sprs.isEmpty ? "Request Parts" : "Request More Parts", icon: "shippingbox.fill", color: Color.appOrange) { showPartsRequestSheet = true }
            }
            if status == .assigned, let wo = workOrder, (wo.partsSubStatus == .ready || wo.partsSubStatus == .approved || wo.partsSubStatus == .none) {
                HStack(spacing: 10) {
                    actionButton(title: "Plan Phases", icon: "list.number", color: Color.appTextPrimary) { showPhasePlanner = true }
                    actionButton(title: "Start Work", icon: "play.fill", color: .purple) { showEstimatedTimeSheet = true }
                }
            }
            if status == .inProgress {
                Button { Task { await markRepairDone() } } label: {
                    HStack(spacing: 8) {
                        if isCompleting { ProgressView().tint(.white) }
                        Image(systemName: "checkmark.seal.fill")
                        Text(allPhasesDone ? "Complete" : "Complete All Phases First")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(allPhasesDone ? Color.green : Color.green.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isCompleting || !allPhasesDone)

                if !phases.isEmpty && !allPhasesDone {
                    Text("\(phases.filter { $0.isCompleted }.count)/\(phases.count) phases completed")
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                }
            }
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(color, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - ETA Sheet

    private var estimatedTimeSheet: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.appOrange.opacity(0.1)).frame(width: 64, height: 64)
                            Image(systemName: "timer").font(.system(size: 28, weight: .light)).foregroundStyle(Color.appOrange)
                        }
                        Text("Set Estimated Time").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                        Text("How long will this repair take?").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.top, 28).padding(.bottom, 20)

                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("Days").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextSecondary).frame(maxWidth: .infinity)
                            Text("Hours").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextSecondary).frame(maxWidth: .infinity)
                            Text("Minutes").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextSecondary).frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24).padding(.bottom, 4)

                        HStack(spacing: 0) {
                            Picker("Days", selection: $estimatedDays) { ForEach(0..<31, id: \.self) { Text($0 == 0 ? "–" : "\($0)d").tag($0) } }.pickerStyle(.wheel).frame(maxWidth: .infinity)
                            Picker("Hours", selection: $estimatedHours) { ForEach(0..<24, id: \.self) { Text($0 == 0 ? "–" : "\($0)h").tag($0) } }.pickerStyle(.wheel).frame(maxWidth: .infinity)
                            Picker("Minutes", selection: $estimatedMinutes) { ForEach(Array(stride(from: 0, through: 60, by: 5)), id: \.self) { Text($0 == 0 ? "0m" : "\($0)m").tag($0) } }.pickerStyle(.wheel).frame(maxWidth: .infinity)
                        }
                        .tint(Color.appOrange).frame(height: 160).padding(.horizontal, 8)
                    }
                    .padding(.vertical, 12)
                    .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appDivider, lineWidth: 1))
                    .padding(.horizontal, 20)

                    let totalMins = estimatedDays * 1440 + estimatedHours * 60 + estimatedMinutes
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill").font(.system(size: 12)).foregroundStyle(Color.appOrange)
                        if totalMins == 0 {
                            Text("Select a duration").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                        } else {
                            Text("ETA: \(etaSummary(days: estimatedDays, hours: estimatedHours, mins: estimatedMinutes))")
                                .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                        }
                    }
                    .padding(.top, 14)

                    if phases.isEmpty {
                        Button { showEstimatedTimeSheet = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showPhasePlanner = true } } label: {
                            Text("Plan Phases First").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color.appOrange)
                                .padding(.horizontal, 12).padding(.vertical, 8).background(Capsule().fill(Color.appOrange.opacity(0.1)))
                        }
                        .padding(.top, 10)
                    }

                    Spacer()

                    Button { Task { await startWork() } } label: {
                        HStack(spacing: 8) {
                            if isStarting { ProgressView().tint(.white).scaleEffect(0.85) }
                            Image(systemName: "play.fill")
                            Text("Start Work Now").font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(totalMins == 0 ? Color.appTextSecondary.opacity(0.35) : Color.purple, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isStarting || totalMins == 0)
                    .padding(.horizontal, 20).padding(.bottom, 28)
                }
            }
            .navigationTitle("Set ETA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEstimatedTimeSheet = false }.foregroundStyle(Color.appOrange)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Phase Planner Sheet (Sierra card style — no List)

    private var phasePlannerSheet: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Header hint
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appOrange)
                        Text("Drag to reorder · Swipe left to delete")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(phasePlanDrafts.indices, id: \.self) { idx in
                                PhaseEditorCard(
                                    draft: $phasePlanDrafts[idx],
                                    phaseNumber: idx + 1,
                                    onDelete: { deleteDraftPhase(at: idx) }
                                )
                            }

                            // Add phase button
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                    phasePlanDrafts.append(.init(title: "", details: "", estimatedMinutes: 60))
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Add Phase")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(Color.appOrange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.appOrange.opacity(0.07))
                                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.appOrange.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Plan Phases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showPhasePlanner = false }.foregroundStyle(Color.appOrange)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await persistPhasePlan() } }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                }
            }
            .onAppear {
                if phasePlanDrafts.isEmpty {
                    if phases.isEmpty {
                        phasePlanDrafts = [.init(title: "", details: "", estimatedMinutes: 60)]
                    } else {
                        phasePlanDrafts = phases.map {
                            .init(title: $0.title, details: $0.description ?? "", estimatedMinutes: $0.estimatedMinutes ?? 60)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Backend Actions

    private func startWork() async {
        isStarting = true; defer { isStarting = false }
        let totalMins = estimatedDays * 1440 + estimatedHours * 60 + estimatedMinutes
        let eta = Date().addingTimeInterval(Double(totalMins * 60))
        if var wo = workOrder {
            wo.estimatedCompletionAt = eta; wo.startedAt = Date(); wo.status = .inProgress
            try? await store.updateWorkOrder(wo)
            if phases.isEmpty { await persistPhasePlan(workOrderId: wo.id, closeSheet: false) }
        }
        if let idx = store.maintenanceTasks.firstIndex(where: { $0.id == task.id }) {
            store.maintenanceTasks[idx].status = .inProgress
            try? await MaintenanceTaskService.updateMaintenanceTask(store.maintenanceTasks[idx])
        }
        showEstimatedTimeSheet = false
    }

    private func deleteDraftPhase(at index: Int) {
        withAnimation { _ = phasePlanDrafts.remove(at: index) }
        if phasePlanDrafts.isEmpty { phasePlanDrafts.append(.init(title: "", details: "", estimatedMinutes: 60)) }
    }

    private func persistPhasePlan(workOrderId: UUID? = nil, closeSheet: Bool = true) async {
        let woId = workOrderId ?? workOrder?.id; guard let woId else { return }
        let clean = phasePlanDrafts
            .map { PhasePlanDraft(title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines), details: $0.details.trimmingCharacters(in: .whitespacesAndNewlines), estimatedMinutes: max(15, $0.estimatedMinutes)) }
            .filter { !$0.title.isEmpty }
        guard !clean.isEmpty else { return }
        for (idx, draft) in clean.enumerated() {
            if phases.indices.contains(idx) {
                try? await store.updatePhasePlan(phaseId: phases[idx].id, phaseNumber: idx + 1, title: draft.title, description: draft.details.isEmpty ? nil : draft.details, estimatedMinutes: draft.estimatedMinutes)
            } else {
                try? await store.createPhase(workOrderId: woId, phaseNumber: idx + 1, title: draft.title, description: draft.details.isEmpty ? nil : draft.details, estimatedMinutes: draft.estimatedMinutes)
            }
        }
        await store.loadWorkOrderPhases(workOrderId: woId)
        if closeSheet { showPhasePlanner = false }
    }

    private func markRepairDone() async {
        isCompleting = true; defer { isCompleting = false }
        try? await store.closeWorkOrder(id: workOrder?.id ?? UUID())
    }

    // MARK: - Helper Views & Functions

    private func priorityBadge(_ p: TaskPriority) -> some View {
        let c = priorityColor(p)
        return HStack(spacing: 4) {
            Image(systemName: priorityIcon(p)).font(.system(size: 10))
            Text(p.rawValue).font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(c).padding(.horizontal, 10).padding(.vertical, 5).background(c.opacity(0.1), in: Capsule())
    }

    private var dueCountdown: String {
        guard task.status == .inProgress, let eta = workOrder?.estimatedCompletionAt else { return "" }
        let r = eta.timeIntervalSince(Date())
        if r <= 0 { return "Overdue" }
        let h = Int(r) / 3600; let m = (Int(r) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m left" : "\(m)m left"
    }

    private var statusBannerText: String {
        if task.status == .assigned, let wo = workOrder, wo.partsSubStatus != .none { return wo.partsSubStatus.displayText }
        return task.status.rawValue
    }

    private func taskStatusColor(_ s: MaintenanceTaskStatus) -> Color {
        switch s { case .pending: .gray; case .assigned: .blue; case .inProgress: .purple; case .completed: .green; case .cancelled: .red }
    }
    private func statusBannerIcon(_ s: MaintenanceTaskStatus) -> String {
        switch s { case .pending: "clock"; case .assigned: "person.badge.clock"; case .inProgress: "wrench.and.screwdriver"; case .completed: "checkmark.seal.fill"; case .cancelled: "xmark.circle" }
    }
    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p { case .low: .green; case .medium: .blue; case .high: .orange; case .urgent: .red }
    }
    private func priorityIcon(_ p: TaskPriority) -> String {
        switch p { case .low: "arrow.down"; case .medium: "minus"; case .high: "arrow.up"; case .urgent: "exclamationmark.2" }
    }
    private func partsStatusColor(_ s: PartsSubStatus) -> Color {
        switch s { case .none: .gray; case .requested, .partiallyReady, .orderPlaced: .orange; case .approved: Color(red: 0.1, green: 0.7, blue: 0.4); case .ready: .green }
    }
    private func sprStatusColor(_ s: SparePartsRequestStatus) -> Color {
        switch s { case .pending: .orange; case .approved: .blue; case .rejected: .red; case .fulfilled: .green }
    }
    private func etaSummary(days: Int, hours: Int, mins: Int) -> String {
        var parts: [String] = []
        if days > 0  { parts.append("\(days) day\(days == 1 ? "" : "s")") }
        if hours > 0 { parts.append("\(hours) hr\(hours == 1 ? "" : "s")") }
        if mins > 0  { parts.append("\(mins) min") }
        return parts.isEmpty ? "–" : parts.joined(separator: " ")
    }
}

// MARK: - Phase Editor Card (Sierra-styled, replaces List rows)

private struct PhaseEditorCard: View {
    @Binding var draft: PhasePlanDraft
    let phaseNumber: Int
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                // Phase number circle
                ZStack {
                    Circle()
                        .fill(Color.appOrange.opacity(0.1))
                        .frame(width: 28, height: 28)
                    Text("\(phaseNumber)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appOrange)
                }
                Text("Phase \(phaseNumber)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            // Title field
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                TextField("e.g. Disassemble engine block", text: $draft.title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appDivider.opacity(0.6), lineWidth: 1))
            }

            // Details field
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes (optional)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                TextField("Add notes or instructions…", text: $draft.details, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appDivider.opacity(0.6), lineWidth: 1))
            }

            // ETA stepper
            HStack {
                Image(systemName: "clock").font(.system(size: 12)).foregroundStyle(Color.appOrange)
                Text("ETA").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        if draft.estimatedMinutes > 15 { draft.estimatedMinutes -= 15 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(draft.estimatedMinutes > 15 ? Color.appOrange : Color.appDivider)
                    }
                    .buttonStyle(.plain)

                    Text(etaLabel(draft.estimatedMinutes))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                        .frame(minWidth: 60, alignment: .center)

                    Button {
                        if draft.estimatedMinutes < 1440 { draft.estimatedMinutes += 15 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(draft.estimatedMinutes < 1440 ? Color.appOrange : Color.appDivider)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    private func etaLabel(_ mins: Int) -> String {
        let h = mins / 60; let m = mins % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

// MARK: - Phase Plan Draft Model

private struct PhasePlanDraft {
    var title: String
    var details: String
    var estimatedMinutes: Int
}
