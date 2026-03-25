import SwiftUI

// MARK: - MaintenanceTaskDetailView
// Layout: header card → vehicle card → status banner → parts/inventory card → history card → action buttons
// ETA picker sheet shown before "Start Work"

struct MaintenanceTaskDetailView: View {

    let task: MaintenanceTask

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showPartsSheet      = false
    @State private var showETASheet        = false
    @State private var isMarkingComplete   = false
    @State private var isStartingWork      = false
    @State private var errorMessage: String? = nil

    // ETA picker state
    @State private var etaDays    = 0
    @State private var etaHours   = 0
    @State private var etaMinutes = 0

    private var vehicle: Vehicle?       { store.vehicle(for: task.vehicleId) }
    private var workOrder: WorkOrder?  { store.workOrder(forMaintenanceTask: task.id) }
    private var sparePartsRequests: [SparePartsRequest] { store.sparePartsRequests(forTask: task.id) }
    private var personnelId: UUID?     { AuthManager.shared.currentUser?.id }

    // Derived flags
    private var partsSubStatus: PartsSubStatus { workOrder?.partsSubStatus ?? .none }
    private var canRequestParts: Bool { task.status == .assigned && sparePartsRequests.isEmpty }
    private var canStartWork: Bool    { partsSubStatus == .ready || partsSubStatus == .approved }
    private var canMarkDone: Bool     { task.status == .inProgress }

    private var isOverdue: Bool {
        guard let eta = workOrder?.estimatedCompletionAt else { return false }
        return eta < Date() && task.status == .inProgress
    }
    private var etaCountdown: String {
        guard let eta = workOrder?.estimatedCompletionAt else { return "" }
        let diff = eta.timeIntervalSince(Date())
        if diff <= 0 { return "Overdue" }
        let h = Int(diff) / 3600, m = (Int(diff) % 3600) / 60
        return h > 0 ? "Due in \(h)h \(m)m" : "Due in \(m)m"
    }

    // Admin name who created the task
    private var assignedByName: String {
        store.staff.first(where: { $0.id == task.createdByAdminId })?.name ?? "Admin"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                taskHeaderCard
                vehicleCard
                statusBanner
                partsInventoryCard
                historyCard
                actionButtons
                    .padding(.bottom, 24)
            }
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Repair Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPartsSheet) {
            SparePartsRequestSheet(task: task)
                .environment(store)
        }
        .sheet(isPresented: $showETASheet) {
            etaPickerSheet
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            if let id = workOrder?.id {
                await store.loadWorkOrderPhases(workOrderId: id)
            }
        }
    }

    // MARK: - 1. Task Header Card

    private var taskHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.appTextPrimary)
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill").font(.caption2)
                        Text(assignedByName).font(.caption)
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
                Label(
                    task.dueDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()),
                    systemImage: "calendar.badge.clock"
                )
                .font(.caption)
                .foregroundStyle(
                    task.dueDate < Date() && task.status != .completed ? .red : Color.appTextSecondary
                )
                Spacer()
                // Work order type pill
                if let wo = workOrder {
                    Text(wo.workOrderType.rawValue.capitalized)
                        .font(.system(size: 10, weight: .semibold))
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

    // MARK: - 2. Vehicle Card

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
                        Text("\(v.manufacturer) \(v.model)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appTextPrimary)
                        Text("\(v.model) • \(v.licensePlate)")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                        Text("VIN: \(v.vin)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(red: 0.65, green: 0.65, blue: 0.68))
                        Text("Odometer: \(Int(v.odometer)) km")
                            .font(.caption2)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    Spacer()
                }

                // Prior repairs for same vehicle
                let priorTasks = store.maintenanceTasks.filter {
                    $0.vehicleId == v.id && $0.id != task.id
                }.prefix(4)

                if !priorTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Previous Repairs")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appTextSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(priorTasks) { r in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(statusColor(r.status).opacity(0.8))
                                            .frame(width: 6, height: 6)
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
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "car").foregroundStyle(Color.appTextSecondary)
                    Text("Vehicle unavailable")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - 3. Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        let (bannerColor, bannerIcon, bannerTitle, bannerSubtitle) = statusBannerContent
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: bannerIcon)
                    .font(.title3)
                    .foregroundStyle(bannerColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bannerTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(bannerColor)
                    if !bannerSubtitle.isEmpty {
                        Text(bannerSubtitle)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .background(bannerColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(bannerColor.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var statusBannerContent: (Color, String, String, String) {
        switch task.status {
        case .pending:
            return (Color(red: 0.20, green: 0.50, blue: 0.90), "clock", "Pending Assignment", "Waiting to be assigned to a technician")
        case .assigned:
            let sub: String = {
                switch partsSubStatus {
                case .none:           return "Request parts from inventory to proceed"
                case .requested:      return "Parts request is pending admin review"
                case .partiallyReady: return "Some parts available — partial order placed"
                case .orderPlaced:    return "Parts ordered — waiting on delivery"
                case .approved:       return "All parts available — ready to start work"
                case .ready:          return "All parts ready — you can start work now"
                }
            }()
            return (Color.appOrange, "person.fill.checkmark", "Assigned – \(partsSubStatus.displayText)", sub)
        case .inProgress:
            if isOverdue {
                return (.red, "exclamationmark.triangle.fill", "Overdue", "Estimated completion time has passed")
            }
            return (.purple, "wrench.fill", "In Progress", etaCountdown)
        case .completed:
            let done = task.completedAt.map { "Completed " + $0.formatted(.dateTime.month(.abbreviated).day().hour().minute()) } ?? "Completed"
            return (Color(red: 0.1, green: 0.7, blue: 0.4), "checkmark.seal.fill", "Repair Done", done)
        case .cancelled:
            return (SierraTheme.Colors.danger, "xmark.circle.fill", "Cancelled", task.rejectionReason ?? "")
        }
    }

    // MARK: - 4. Parts / Inventory Card

    private var partsInventoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("PARTS & INVENTORY", systemImage: "shippingbox.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .kerning(1)
                Spacer()
                // Overall summary badge
                if !sparePartsRequests.isEmpty {
                    let allFulfilled = sparePartsRequests.allSatisfy { $0.status == .fulfilled }
                    if allFulfilled {
                        Label("All Fulfilled", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    } else {
                        let pending = sparePartsRequests.filter { $0.status == .pending || $0.status == .approved }.count
                        Label("\(pending) pending", systemImage: "clock.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appOrange)
                    }
                }
            }

            if sparePartsRequests.isEmpty {
                Text("No parts requested yet")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                ForEach(sparePartsRequests) { spr in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(sprStatusColor(spr.status))
                            .frame(width: 8, height: 8)
                        Text(spr.partName)
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("x\(spr.quantity)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.appTextSecondary)
                            // Partial info
                            if spr.quantityOnOrder > 0 {
                                Text("\(spr.quantityAllocated) ready · \(spr.quantityOnOrder) on order")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.appOrange)
                            }
                        }
                        if let pn = spr.partNumber {
                            Text(pn)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(red: 0.65, green: 0.65, blue: 0.68))
                        }
                    }
                }

                // Parts request status summary
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Parts Request")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appTextSecondary)
                        Text("\(sparePartsRequests.count) item(s) · \(partsSubStatus.displayText)")
                            .font(.caption)
                            .foregroundStyle(Color.appTextPrimary)
                    }
                    Spacer()
                    Text(partsSubStatus.displayText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(
                            partsSubStatus == .ready || partsSubStatus == .approved
                                ? Color.green
                                : Color.appOrange,
                            in: Capsule()
                        )
                }
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - 5. History Card

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("HISTORY", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .kerning(0.8)
                Spacer()
                Text("\(historyEvents.count) events")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                historySubheader("This Task", icon: "wrench.fill", color: Color.appOrange)
                ForEach(Array(historyEvents.enumerated()), id: \.offset) { idx, entry in
                    historyRow(
                        icon: entry.icon,
                        color: entry.color,
                        title: entry.title,
                        detail: entry.detail,
                        date: entry.date,
                        isLast: idx == historyEvents.count - 1
                    )
                }
            }
        }
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private struct HistoryEvent {
        let icon: String
        let color: Color
        let title: String
        let detail: String
        let date: Date
    }

    private var historyEvents: [HistoryEvent] {
        var events: [HistoryEvent] = []
        events.append(.init(
            icon: "plus.circle.fill",
            color: Color.appOrange,
            title: "Task Created",
            detail: "Priority: \(task.priority.rawValue) · Type: \(task.taskType.rawValue)",
            date: task.createdAt
        ))
        if let approvedAt = task.approvedAt {
            events.append(.init(
                icon: "checkmark.circle.fill",
                color: .green,
                title: "Task Approved & Assigned",
                detail: "Assigned to you",
                date: approvedAt
            ))
        }
        for spr in sparePartsRequests {
            events.append(.init(
                icon: "shippingbox.fill",
                color: Color(red: 0.20, green: 0.50, blue: 0.90),
                title: "Parts Requested",
                detail: "\(spr.partName) · qty \(spr.quantity)",
                date: spr.createdAt
            ))
            if let reviewedAt = spr.reviewedAt {
                let isApproved = spr.status == .approved || spr.status == .fulfilled
                events.append(.init(
                    icon: isApproved ? "checkmark.circle" : "xmark.circle",
                    color: isApproved ? .green : .red,
                    title: isApproved ? "Parts Approved" : "Parts Rejected",
                    detail: spr.partName,
                    date: reviewedAt
                ))
            }
            if let fulfilledAt = spr.fulfilledAt {
                events.append(.init(
                    icon: "checkmark.seal.fill",
                    color: .green,
                    title: "Parts Fulfilled",
                    detail: "\(spr.partName) · \(spr.quantityAllocated)/\(spr.quantity) allocated",
                    date: fulfilledAt
                ))
            }
        }
        if let startedAt = workOrder?.startedAt {
            events.append(.init(
                icon: "play.fill",
                color: .purple,
                title: "Work Started",
                detail: "Repair in progress",
                date: startedAt
            ))
        }
        if let completedAt = task.completedAt {
            events.append(.init(
                icon: "checkmark.seal.fill",
                color: .green,
                title: "Repair Completed",
                detail: "Task marked as done",
                date: completedAt
            ))
        }
        return events.sorted { $0.date < $1.date }
    }

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

    // MARK: - 6. Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Request Parts (when assigned & no SPRs yet)
            if canRequestParts {
                Button {
                    showPartsSheet = true
                } label: {
                    Label("Request Parts from Inventory", systemImage: "shippingbox.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.appOrange, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
            } else if !canRequestParts && task.status == .assigned && !sparePartsRequests.isEmpty {
                // Add more parts
                Button {
                    showPartsSheet = true
                } label: {
                    Label("Add More Parts", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appOrange)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.appOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.appOrange.opacity(0.3)))
                }
                .padding(.horizontal, 16)
            }

            // Start Work (parts ready → show ETA picker first)
            if canStartWork {
                Button {
                    etaDays = 0; etaHours = 0; etaMinutes = 0
                    showETASheet = true
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

            // Mark Repair Done (in progress)
            if canMarkDone {
                Button {
                    Task { await markDone() }
                } label: {
                    HStack {
                        if isMarkingComplete { ProgressView().tint(.white) }
                        Label("Mark Repair Done", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isMarkingComplete)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - ETA Picker Sheet

    private var etaPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Icon + title
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

                    // Wheel pickers
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("Days").font(.caption.weight(.semibold)).foregroundStyle(Color.appTextSecondary).frame(maxWidth: .infinity)
                            Text("Hours").font(.caption.weight(.semibold)).foregroundStyle(Color.appTextSecondary).frame(maxWidth: .infinity)
                            Text("Minutes").font(.caption.weight(.semibold)).foregroundStyle(Color.appTextSecondary).frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)

                        HStack(spacing: 0) {
                            Picker("Days", selection: $etaDays) {
                                ForEach(0..<31, id: \.self) { d in
                                    Text(d == 0 ? "–" : "\(d)d").tag(d)
                                }
                            }
                            .pickerStyle(.wheel).frame(maxWidth: .infinity)

                            Picker("Hours", selection: $etaHours) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(h == 0 ? "–" : "\(h)h").tag(h)
                                }
                            }
                            .pickerStyle(.wheel).frame(maxWidth: .infinity)

                            Picker("Minutes", selection: $etaMinutes) {
                                ForEach(Array(stride(from: 0, through: 60, by: 5)), id: \.self) { m in
                                    Text(m == 0 ? "0m" : "\(m)m").tag(m)
                                }
                            }
                            .pickerStyle(.wheel).frame(maxWidth: .infinity)
                        }
                        .tint(Color.appOrange)
                        .frame(height: 160)
                        .padding(.horizontal, 8)
                    }
                    .padding(.vertical, 12)
                    .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)

                    // ETA summary line
                    let totalMins = etaDays * 1440 + etaHours * 60 + etaMinutes
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill").font(.caption).foregroundStyle(Color.appOrange)
                        if totalMins == 0 {
                            Text("Select an estimated duration above")
                                .font(.caption).foregroundStyle(Color.appTextSecondary)
                        } else {
                            Text("ETA: ").font(.caption).foregroundStyle(Color.appTextSecondary)
                            + Text(etaSummary(days: etaDays, hours: etaHours, mins: etaMinutes))
                                .font(.caption.weight(.semibold)).foregroundStyle(Color.appTextPrimary)
                        }
                    }
                    .padding(.top, 14)

                    Spacer()

                    // Start button
                    Button {
                        Task { await startWork(totalMinutes: totalMins) }
                    } label: {
                        HStack(spacing: 8) {
                            if isStartingWork { ProgressView().tint(.white).scaleEffect(0.85) }
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
                    .disabled(isStartingWork || totalMins == 0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Set ETA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showETASheet = false }
                        .foregroundStyle(Color.appOrange)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Helpers

    private func priorityBadge(_ p: TaskPriority) -> some View {
        let color = priorityColor(p)
        return HStack(spacing: 4) {
            Image(systemName: priorityIcon(p)).font(.system(size: 10))
            Text(p.rawValue).font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.1), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 0.5))
    }

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .urgent: return Color(red: 0.85, green: 0.18, blue: 0.15)
        case .high:   return Color.appOrange
        case .medium: return Color(red: 0.20, green: 0.50, blue: 0.90)
        case .low:    return Color.appTextSecondary
        }
    }

    private func priorityIcon(_ p: TaskPriority) -> String {
        switch p {
        case .urgent: return "flame.fill"
        case .high:   return "exclamationmark.triangle.fill"
        case .medium: return "arrow.right.circle.fill"
        case .low:    return "minus.circle.fill"
        }
    }

    private func statusColor(_ s: MaintenanceTaskStatus) -> Color {
        switch s {
        case .pending:    return Color(red: 0.20, green: 0.50, blue: 0.90)
        case .assigned:   return Color.appOrange
        case .inProgress: return .purple
        case .completed:  return .green
        case .cancelled:  return SierraTheme.Colors.danger
        }
    }

    private func sprStatusColor(_ s: SparePartsRequestStatus) -> Color {
        switch s {
        case .pending:   return Color.appOrange
        case .approved:  return Color(red: 0.20, green: 0.50, blue: 0.90)
        case .fulfilled: return .green
        case .rejected:  return .red
        }
    }

    private func etaSummary(days: Int, hours: Int, mins: Int) -> String {
        var parts: [String] = []
        if days  > 0 { parts.append("\(days) day\(days == 1 ? "" : "s")") }
        if hours > 0 { parts.append("\(hours) hr\(hours == 1 ? "" : "s")") }
        if mins  > 0 { parts.append("\(mins) min") }
        return parts.isEmpty ? "–" : parts.joined(separator: " ")
    }

    // MARK: - Actions

    private func startWork(totalMinutes: Int) async {
        guard let wo = workOrder, let pid = personnelId else { return }
        isStartingWork = true
        defer { isStartingWork = false }

        let eta = Date().addingTimeInterval(Double(totalMinutes * 60))
        do {
            // Set ETA on work order
            try await WorkOrderService.setEstimatedCompletion(workOrderId: wo.id, estimatedAt: eta)
            // Update task status to inProgress
            try await MaintenanceTaskService.updateMaintenanceTaskStatus(id: task.id, status: .inProgress)
            // Update work order status
            var updated = wo
            updated.status = .inProgress
            updated.startedAt = Date()
            try await WorkOrderService.updateWorkOrder(updated)
            // Reload
            await store.loadMaintenanceData(staffId: pid)
            showETASheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markDone() async {
        guard let pid = personnelId, let wo = workOrder else { return }
        isMarkingComplete = true
        defer { isMarkingComplete = false }
        do {
            try await MaintenanceTaskService.updateMaintenanceTaskStatus(id: task.id, status: .completed)
            var updated = wo
            updated.status = .completed
            updated.completedAt = Date()
            try await WorkOrderService.updateWorkOrder(updated)
            await store.loadMaintenanceData(staffId: pid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
