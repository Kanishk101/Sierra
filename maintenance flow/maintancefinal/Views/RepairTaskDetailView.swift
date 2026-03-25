import SwiftUI

struct RepairTaskDetailView: View {
    @State private var viewModel: RepairDetailViewModel
    var onUpdate: (RepairTask) -> Void
    @Environment(\.dismiss) private var dismiss

    init(task: RepairTask, onUpdate: @escaping (RepairTask) -> Void) {
        _viewModel = State(initialValue: RepairDetailViewModel(task: task))
        self.onUpdate = onUpdate
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
        .sheet(isPresented: $viewModel.showPartsRequestSheet) {
            PartsRequestSheet(task: viewModel.task) { parts in
                viewModel.submitPartsRequest(parts)
                onUpdate(viewModel.task)
            }
        }
        .sheet(isPresented: $viewModel.showEstimatedTimeSheet) {
            estimatedTimeSheet
        }
        .onChange(of: viewModel.task) { _, newTask in
            onUpdate(newTask)
        }
    }

    // MARK: - Task Header
    private var taskHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.task.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.appTextPrimary)
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill").font(.caption2)
                        Text(viewModel.task.assignedBy)
                            .font(.caption)
                    }
                    .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                priorityBadge(viewModel.task.priority)
            }

            Text(viewModel.task.description)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Label(viewModel.task.dueDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()), systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
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
        let v = RepairStaticData.vehicle(for: viewModel.task.vehicleId)
        return VStack(alignment: .leading, spacing: 10) {
            Label("VEHICLE", systemImage: "car.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)
                .kerning(1)

            if let v = v {
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

                let priorRepairs = RepairStaticData.repairTasks.filter {
                    $0.vehicleId == v.id && $0.id != viewModel.task.id
                }
                if !priorRepairs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Previous Repairs").font(.caption.weight(.medium)).foregroundStyle(Color.appTextSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(priorRepairs) { r in
                                    HStack(spacing: 4) {
                                        Circle().fill(r.status.color).frame(width: 6, height: 6)
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
        let status = viewModel.task.status
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: status.icon)
                    .font(.title3)
                    .foregroundStyle(status.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(status.color)
                    if status == .underMaintenance {
                        Text(viewModel.dueCountdown)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    } else if status == .partsReady {
                        Text("All parts available — you can start work now")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    } else if status == .repairDone, let done = viewModel.task.completedAt {
                        Text("Completed " + done.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(.caption).foregroundStyle(Color.appTextSecondary)
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .background(status.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(status.color.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Inventory Card
    private var inventoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("INVENTORY REQUIREMENTS", systemImage: "shippingbox.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .kerning(1)
                Spacer()
                let allAvail = viewModel.task.inventoryRequirements.allSatisfy { $0.isAvailable }
                if allAvail {
                    Label("All Available", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                } else {
                    let missing = viewModel.task.inventoryRequirements.filter { !$0.isAvailable }.count
                    Label("\(missing) missing", systemImage: "xmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }
            }

            if viewModel.task.inventoryRequirements.isEmpty {
                Text("No inventory requirements listed")
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
            } else {
                ForEach(viewModel.task.inventoryRequirements) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(item.isAvailable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(item.name).font(.subheadline).foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Text("x\(item.quantity)").font(.caption.weight(.medium)).foregroundStyle(Color.appTextSecondary)
                        Text(item.partNumber)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(red: 0.65, green: 0.65, blue: 0.68))
                    }
                }
            }

            if let req = viewModel.task.partsRequest {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Parts Request").font(.caption.weight(.medium)).foregroundStyle(Color.appTextSecondary)
                        Text("\(req.items.count) item(s) • " + req.status.rawValue)
                            .font(.caption).foregroundStyle(Color.appTextPrimary)
                    }
                    Spacer()
                    Text(req.status.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(req.status == .fulfilled ? Color.green : Color.orange, in: Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - History
    private var historyCard: some View {
        let vehicleId = viewModel.task.vehicleId
        let prevRepairs = RepairStaticData.repairTasks.filter {
            $0.vehicleId == vehicleId && $0.id != viewModel.task.id
        }
        let prevServices = RepairStaticData.serviceTasks.filter {
            $0.vehicleId == vehicleId
        }

        return VStack(alignment: .leading, spacing: 0) {
            // ── Card header ──────────────────────────────────────────────
            HStack {
                Label("HISTORY", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .kerning(0.8)
                Spacer()
                Text("\(viewModel.task.history.count) events")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // ── Current task timeline ─────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                historySubheader("This Task", icon: "wrench.fill", color: Color.appOrange)

                ForEach(Array(viewModel.task.history.reversed().enumerated()), id: \.element.id) { idx, entry in
                    historyRow(
                        icon: entry.icon,
                        color: entry.color,
                        title: entry.title,
                        detail: entry.detail,
                        date: entry.date,
                        isLast: idx == viewModel.task.history.count - 1
                    )
                }
            }

            // ── Previous repairs for same vehicle ─────────────────────
            if !prevRepairs.isEmpty {
                Divider().padding(.top, 4)
                VStack(alignment: .leading, spacing: 0) {
                    historySubheader("Previous Repairs – Same Vehicle", icon: "wrench.and.screwdriver", color: .purple)
                    ForEach(Array(prevRepairs.enumerated()), id: \.element.id) { idx, repair in
                        historyRow(
                            icon: repair.status.icon,
                            color: repair.status.color,
                            title: repair.title,
                            detail: "\(repair.status.rawValue) · \(repair.priority.rawValue) priority",
                            date: repair.createdAt,
                            isLast: idx == prevRepairs.count - 1
                        )
                    }
                }
            }

            // ── Previous services for same vehicle ────────────────────
            if !prevServices.isEmpty {
                Divider().padding(.top, 4)
                VStack(alignment: .leading, spacing: 0) {
                    historySubheader("Previous Services – Same Vehicle", icon: "calendar.badge.checkmark", color: .teal)
                    ForEach(Array(prevServices.enumerated()), id: \.element.id) { idx, service in
                        historyRow(
                            icon: "calendar.badge.checkmark",
                            color: service.status.color,
                            title: service.title,
                            detail: "\(service.serviceType.rawValue) · \(service.status.rawValue)",
                            date: service.scheduledDate,
                            isLast: idx == prevServices.count - 1
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
            // Timeline track
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

    // MARK: - Action Buttons
    @ViewBuilder
    private var actionButtons: some View {
        let status = viewModel.task.status
        VStack(spacing: 10) {
            if status == .assigned && viewModel.task.partsRequest == nil {
                Button {
                    viewModel.showPartsRequestSheet = true
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

            if status == .partsReady {
                Button {
                    viewModel.showEstimatedTimeSheet = true
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

            if status == .underMaintenance {
                Button {
                    viewModel.markRepairDone()
                } label: {
                    HStack {
                        if viewModel.isCompleting { ProgressView().tint(.white) }
                        Label("Mark Repair Done", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.isCompleting)
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
                        // Column labels
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
                            // Days: minimum 0, shown 0–30, but min selectable is highlighted as 0
                            // No hard minimum—admin can set 0 days. Per spec: "min 10" means the list starts from 0 but default is 0.
                            Picker("Days", selection: $viewModel.estimatedDays) {
                                ForEach(0..<31, id: \.self) { d in
                                    Text(d == 0 ? "–" : "\(d)d").tag(d)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Hours", selection: $viewModel.estimatedHours) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(h == 0 ? "–" : "\(h)h").tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Minutes", selection: $viewModel.estimatedMinutes) {
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
                    let totalMins = viewModel.estimatedDays * 1440 + viewModel.estimatedHours * 60 + viewModel.estimatedMinutes
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill").font(.caption).foregroundStyle(Color.appOrange)
                        if totalMins == 0 {
                            Text("Select an estimated duration above")
                                .font(.caption).foregroundStyle(Color.appTextSecondary)
                        } else {
                            Text("ETA: ")
                                .font(.caption).foregroundStyle(Color.appTextSecondary)
                            + Text(etaSummary(days: viewModel.estimatedDays,
                                             hours: viewModel.estimatedHours,
                                             mins: viewModel.estimatedMinutes))
                                .font(.caption.weight(.semibold)).foregroundStyle(Color.appTextPrimary)
                        }
                    }
                    .padding(.top, 14)

                    Spacer()

                    // Start button
                    Button {
                        viewModel.startWork()
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isStarting { ProgressView().tint(.white).scaleEffect(0.85) }
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
                    .disabled(viewModel.isStarting || totalMins == 0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Set ETA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showEstimatedTimeSheet = false }
                        .foregroundStyle(Color.appOrange)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func etaSummary(days: Int, hours: Int, mins: Int) -> String {
        var parts: [String] = []
        if days > 0  { parts.append("\(days) day\(days == 1 ? "" : "s")") }
        if hours > 0 { parts.append("\(hours) hr\(hours == 1 ? "" : "s")") }
        if mins > 0  { parts.append("\(mins) min") }
        return parts.isEmpty ? "–" : parts.joined(separator: " ")
    }

    private func priorityBadge(_ p: MTaskPriority) -> some View {
        HStack(spacing: 4) {
            Image(systemName: p.icon).font(.system(size: 10))
            Text(p.rawValue).font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(p.color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(p.bgColor)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(p.borderColor, lineWidth: 0.5))
    }
}
