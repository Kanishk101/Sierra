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

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }
    private var workOrder: WorkOrder? { store.workOrder(forMaintenanceTask: task.id) }
    private var vehicle: Vehicle? { store.vehicle(for: task.vehicleId) }
    private var sprs: [SparePartsRequest] { store.sparePartsRequests(forTask: task.id) }
    private var assignedBy: String {
        store.staffMember(for: task.createdByAdminId)?.name ?? "Admin"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                taskHeaderCard
                vehicleCard
                statusBanner
                inventoryCard
                historyCard
                actionButtons
            }
            .padding(.bottom, 32)
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Repair Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPartsRequestSheet) {
            SparePartsRequestSheet(task: task)
                .environment(store)
        }
        .sheet(isPresented: $showEstimatedTimeSheet) {
            estimatedTimeSheet
        }
    }

    // MARK: - Task Header Card

    private var taskHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.appTextPrimary)
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill").font(.caption2)
                        Text(assignedBy)
                            .font(.caption)
                    }
                    .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                priorityBadge(task.priority)
            }

            Text(task.taskDescription)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Label(task.dueDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()), systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                if let wo = workOrder {
                    Text(wo.workOrderType.rawValue.capitalized)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.appOrange)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.appOrange.opacity(0.1), in: Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Vehicle Card

    private var vehicleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("VEHICLE", systemImage: "car.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)
                .kerning(1)

            if let v = vehicle {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.appOrange.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "car.fill")
                                .font(.title2)
                                .foregroundStyle(Color.appOrange)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.appTextPrimary)
                        Text("\(v.model) • \(v.licensePlate)").font(.caption).foregroundStyle(Color.appTextSecondary)
                        Text("VIN: \(v.vin)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color(red: 0.65, green: 0.65, blue: 0.68))
                        Text("Odometer: \(Int(v.odometer)) km").font(.caption2).foregroundStyle(Color.appTextSecondary)
                    }
                    Spacer()
                }

                // Prior repairs for same vehicle
                let priorRepairs = store.maintenanceTasks.filter {
                    $0.vehicleId == v.id && $0.id != task.id
                }
                if !priorRepairs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Previous Repairs").font(.caption.weight(.medium)).foregroundStyle(Color.appTextSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(priorRepairs.prefix(6)) { r in
                                    HStack(spacing: 4) {
                                        Circle().fill(taskStatusColor(r.status)).frame(width: 6, height: 6)
                                        Text(r.title)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(Color.appOrange)
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.appOrange.opacity(0.1), in: Capsule())
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        let status = task.status
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: statusBannerIcon(status))
                    .font(.title3)
                    .foregroundStyle(taskStatusColor(status))
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusBannerText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(taskStatusColor(status))
                    if status == .inProgress {
                        Text(dueCountdown)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    } else if let wo = workOrder, wo.partsSubStatus == .ready || wo.partsSubStatus == .approved {
                        Text("All parts available — you can start work now")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    } else if status == .completed, let done = task.completedAt {
                        Text("Completed " + done.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(.caption).foregroundStyle(Color.appTextSecondary)
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .background(taskStatusColor(status).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(taskStatusColor(status).opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Inventory Card

    private var inventoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("PARTS & INVENTORY", systemImage: "shippingbox.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .kerning(1)
                Spacer()
                if let wo = workOrder {
                    Label(wo.partsSubStatus.displayText, systemImage: wo.partsSubStatus.icon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(partsStatusColor(wo.partsSubStatus))
                }
            }

            if sprs.isEmpty {
                Text("No parts requested yet")
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
            } else {
                ForEach(sprs) { spr in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(spr.status == .fulfilled ? Color.green :
                                    spr.status == .approved ? Color(red: 0.1, green: 0.7, blue: 0.4) :
                                    spr.status == .rejected ? Color.red : Color.orange)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(spr.partName)
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextPrimary)
                            if spr.quantityAllocated > 0 || spr.quantityOnOrder > 0 {
                                Text("\(spr.quantityAllocated) allocated · \(spr.quantityOnOrder) on order")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        Spacer()
                        Text("x\(spr.quantity)").font(.caption.weight(.medium)).foregroundStyle(Color.appTextSecondary)
                        if let pn = spr.partNumber, !pn.isEmpty {
                            Text(pn)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(red: 0.65, green: 0.65, blue: 0.68))
                        }
                    }
                }

                // Overall parts request status
                if !sprs.isEmpty {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Parts Request").font(.caption.weight(.medium)).foregroundStyle(Color.appTextSecondary)
                            let pending = sprs.filter { $0.status == .pending }.count
                            let approved = sprs.filter { $0.status == .approved }.count
                            let fulfilled = sprs.filter { $0.status == .fulfilled }.count
                            Text("\(sprs.count) item(s) • \(pending) pending · \(approved) approved · \(fulfilled) fulfilled")
                                .font(.caption).foregroundStyle(Color.appTextPrimary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - History Card

    private var historyCard: some View {
        let priorRepairs = store.maintenanceTasks.filter {
            $0.vehicleId == task.vehicleId && $0.id != task.id
        }
        let timelineEntries = buildTimeline()

        return VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack {
                Label("HISTORY", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .kerning(0.8)
                Spacer()
                Text("\(timelineEntries.count) events")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Current task timeline
            VStack(alignment: .leading, spacing: 0) {
                historySubheader("This Task", icon: "wrench.fill", color: Color.appOrange)

                ForEach(Array(timelineEntries.enumerated()), id: \.element.id) { idx, entry in
                    historyRow(
                        icon: entry.icon,
                        color: entry.color,
                        title: entry.title,
                        detail: entry.detail,
                        date: entry.date,
                        isLast: idx == timelineEntries.count - 1
                    )
                }
            }

            // Previous repairs for same vehicle
            if !priorRepairs.isEmpty {
                Divider().padding(.top, 4)
                VStack(alignment: .leading, spacing: 0) {
                    historySubheader("Previous Repairs – Same Vehicle", icon: "wrench.and.screwdriver", color: .purple)
                    ForEach(Array(priorRepairs.prefix(5).enumerated()), id: \.element.id) { idx, repair in
                        historyRow(
                            icon: statusBannerIcon(repair.status),
                            color: taskStatusColor(repair.status),
                            title: repair.title,
                            detail: "\(repair.status.rawValue) · \(repair.priority.rawValue) priority",
                            date: repair.createdAt,
                            isLast: idx == min(priorRepairs.count, 5) - 1
                        )
                    }
                }
            }

            Spacer(minLength: 4)
        }
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        let status = task.status
        VStack(spacing: 10) {
            // Request Parts — only if assigned and no parts requested yet
            if status == .assigned && sprs.isEmpty {
                Button {
                    showPartsRequestSheet = true
                } label: {
                    Label("Request Parts from Inventory", systemImage: "shippingbox.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.appOrange, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
            }

            // Start Work — when parts are ready/approved or no parts needed
            if status == .assigned,
               let wo = workOrder,
               (wo.partsSubStatus == .ready || wo.partsSubStatus == .approved || wo.partsSubStatus == .none) {
                Button {
                    showEstimatedTimeSheet = true
                } label: {
                    Label("Start Work", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.purple, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
            }

            // Mark Repair Done
            if status == .inProgress {
                Button {
                    Task { await markRepairDone() }
                } label: {
                    HStack {
                        if isCompleting { ProgressView().tint(.white) }
                        Label("Mark Repair Done", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isCompleting)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Estimated Time Sheet

    private var estimatedTimeSheet: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Header
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
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)
                        Text("How long will this repair take?")
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                    // Picker card
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("Days").font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appTextSecondary)
                                .frame(maxWidth: .infinity)
                            Text("Hours").font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appTextSecondary)
                                .frame(maxWidth: .infinity)
                            Text("Minutes").font(.caption.weight(.semibold))
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
                    .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)

                    // ETA summary
                    let totalMins = estimatedDays * 1440 + estimatedHours * 60 + estimatedMinutes
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill").font(.caption).foregroundStyle(Color.appOrange)
                        if totalMins == 0 {
                            Text("Select an estimated duration above")
                                .font(.caption).foregroundStyle(Color.appTextSecondary)
                        } else {
                            Text("ETA: ")
                                .font(.caption).foregroundStyle(Color.appTextSecondary)
                            + Text(etaSummary(days: estimatedDays, hours: estimatedHours, mins: estimatedMinutes))
                                .font(.caption.weight(.semibold)).foregroundStyle(Color.appTextPrimary)
                        }
                    }
                    .padding(.top, 14)

                    Spacer()

                    // Start button
                    Button {
                        Task { await startWork() }
                    } label: {
                        HStack(spacing: 8) {
                            if isStarting { ProgressView().tint(.white).scaleEffect(0.85) }
                            Image(systemName: "play.fill")
                            Text("Start Work Now").fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(
                            totalMins == 0 ? Color.appTextSecondary.opacity(0.35) : Color.purple,
                            in: RoundedRectangle(cornerRadius: 14)
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

        // Update work order with ETA and started status
        if var wo = workOrder {
            wo.estimatedCompletionAt = eta
            wo.startedAt = Date()
            wo.status = .inProgress
            try? await store.updateWorkOrder(wo)
        }

        // Update task status
        if let idx = store.maintenanceTasks.firstIndex(where: { $0.id == task.id }) {
            store.maintenanceTasks[idx].status = .inProgress
            try? await MaintenanceTaskService.updateMaintenanceTask(store.maintenanceTasks[idx])
        }

        showEstimatedTimeSheet = false
    }

    private func markRepairDone() async {
        isCompleting = true
        defer { isCompleting = false }

        // Close work order
        try? await store.closeWorkOrder(id: workOrder?.id ?? UUID())

        // Task status is updated by closeWorkOrder automatically
    }

    // MARK: - Timeline Builder

    private struct TimelineEntry: Identifiable {
        let id = UUID()
        let date: Date
        let title: String
        let detail: String
        let icon: String
        let color: Color
    }

    private func buildTimeline() -> [TimelineEntry] {
        var entries: [TimelineEntry] = []

        // Created
        entries.append(TimelineEntry(
            date: task.createdAt,
            title: "Task Created",
            detail: "Created by \(assignedBy)",
            icon: "plus.circle.fill",
            color: .blue
        ))

        // Approved
        if let approvedAt = task.approvedAt {
            entries.append(TimelineEntry(
                date: approvedAt,
                title: "Task Approved",
                detail: "Approved for work",
                icon: "checkmark.circle.fill",
                color: .green
            ))
        }

        // Parts requested
        if let firstSPR = sprs.sorted(by: { $0.createdAt < $1.createdAt }).first {
            entries.append(TimelineEntry(
                date: firstSPR.createdAt,
                title: "Parts Requested",
                detail: "\(sprs.count) item(s) submitted to admin",
                icon: "shippingbox",
                color: .orange
            ))
        }

        // Parts reviewed
        if let reviewedSPR = sprs.first(where: { $0.reviewedAt != nil }), let reviewedAt = reviewedSPR.reviewedAt {
            entries.append(TimelineEntry(
                date: reviewedAt,
                title: "Parts Reviewed",
                detail: reviewedSPR.status == .approved ? "Parts approved" : "Parts \(reviewedSPR.status.rawValue.lowercased())",
                icon: reviewedSPR.status == .approved ? "checkmark.circle" : "xmark.circle",
                color: reviewedSPR.status == .approved ? Color(red: 0.1, green: 0.7, blue: 0.4) : .red
            ))
        }

        // Work started
        if let wo = workOrder, let started = wo.startedAt {
            var etaLabel = ""
            if let eta = wo.estimatedCompletionAt {
                let remaining = eta.timeIntervalSince(started)
                let h = Int(remaining) / 3600
                let m = (Int(remaining) % 3600) / 60
                if h > 0 { etaLabel = "ETA \(h)h \(m)m" } else { etaLabel = "ETA \(m)m" }
            }
            entries.append(TimelineEntry(
                date: started,
                title: "Work Started",
                detail: etaLabel.isEmpty ? "Repair in progress" : etaLabel,
                icon: "wrench.and.screwdriver.fill",
                color: .purple
            ))
        }

        // Completed
        if let completed = task.completedAt {
            entries.append(TimelineEntry(
                date: completed,
                title: "Repair Done",
                detail: "Task completed successfully",
                icon: "checkmark.seal.fill",
                color: .green
            ))
        }

        return entries.sorted { $0.date > $1.date }
    }

    // MARK: - Reusable Sub-views

    private func historySubheader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .kerning(0.5)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func historyRow(icon: String, color: Color, title: String, detail: String, date: Date, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 34, height: 34)
                    Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.appDivider)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                Text(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appTextSecondary.opacity(0.7))
            }
            .padding(.bottom, isLast ? 0 : 12)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, isLast ? 16 : 0)
    }

    private func priorityBadge(_ p: TaskPriority) -> some View {
        let color = priorityColor(p)
        return HStack(spacing: 4) {
            Image(systemName: priorityIcon(p)).font(.system(size: 10))
            Text(p.rawValue).font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 0.5))
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

    private func etaSummary(days: Int, hours: Int, mins: Int) -> String {
        var parts: [String] = []
        if days > 0  { parts.append("\(days) day\(days == 1 ? "" : "s")") }
        if hours > 0 { parts.append("\(hours) hr\(hours == 1 ? "" : "s")") }
        if mins > 0  { parts.append("\(mins) min") }
        return parts.isEmpty ? "–" : parts.joined(separator: " ")
    }
}
