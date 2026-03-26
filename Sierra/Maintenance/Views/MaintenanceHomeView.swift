import SwiftUI

/// Maintenance home screen — mirrors DriverHomeView exactly.
/// Gradient header · active task banner · summary stats card · recent tasks.
struct MaintenanceHomeView: View {

    @Environment(AppDataStore.self) private var store
    @State private var showProfile = false
    @State private var availabilitySwitch = false
    @State private var isUpdatingAvailability = false
    @State private var showToast = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var toastPulseScale: CGFloat = 1.0

    private var user: AuthUser? { AuthManager.shared.currentUser }

    private var staffMember: StaffMember? {
        guard let id = user?.id else { return nil }
        return store.staff.first { $0.id == id }
    }

    private var currentUserId: UUID { user?.id ?? UUID() }
    private var isAvailable: Bool { staffMember?.availability == .available }

    private var availabilityBinding: Binding<Bool> {
        Binding(
            get: { availabilitySwitch },
            set: { newValue in requestAvailabilityChange(newValue) }
        )
    }

    private var myTasks: [MaintenanceTask] {
        store.maintenanceTasks
            .filter { $0.assignedToId == currentUserId }
            .sorted {
                if $0.status == .inProgress && $1.status != .inProgress { return true }
                if $1.status == .inProgress && $0.status != .inProgress { return false }
                return $0.dueDate < $1.dueDate
            }
    }

    private var activeTasks: [MaintenanceTask] { myTasks.filter { $0.status == .inProgress } }
    private var assignedTasks: [MaintenanceTask] { myTasks.filter { $0.status == .assigned } }
    private var completedTasks: [MaintenanceTask] { myTasks.filter { $0.status == .completed } }

    private var urgentTasks: [MaintenanceTask] {
        myTasks.filter {
            $0.priority == .urgent &&
            ($0.status == .assigned || $0.status == .inProgress)
        }
    }

    private var activePendingTasks: [MaintenanceTask] {
        Array(myTasks.filter {
            $0.status == .assigned || $0.status == .inProgress
        }.prefix(3))
    }

    var body: some View {
        ZStack {
            Color.appSurface.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection

                    VStack(spacing: 16) {
                        if let active = activeTasks.first {
                            activeTaskBanner(active)
                                .padding(.top, -30)
                        }

                        summaryCard

                        if !urgentTasks.isEmpty {
                            urgentAlertBanner
                        }

                        if !activePendingTasks.isEmpty {
                            recentTasksSection
                        } else {
                            emptyState.padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .refreshable {
                await store.loadMaintenanceData(staffId: currentUserId)
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: MaintenanceTask.self) { task in
            MaintenanceTaskDetailView(task: task)
                .environment(store)
        }
        .sheet(isPresented: $showProfile) {
            MaintenanceProfileView()
                .environment(store)
                .presentationDetents([.large])
        }
        .overlay {
            if showToast, let message = toastMessage {
                availabilityToast(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(50)
            }
        }
        .onAppear {
            availabilitySwitch = isAvailable
            Task { await store.loadMaintenanceData(staffId: currentUserId) }
        }
        .onChange(of: isAvailable) { _, newValue in
            availabilitySwitch = newValue
        }
    }

    private var headerSection: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appAmber, Color.appOrange, Color.appDeepOrange.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(colors: [Color.white.opacity(0.25), Color.clear],
                           center: .topLeading, startRadius: 20, endRadius: 300)
            RadialGradient(colors: [Color.appDeepOrange.opacity(0.4), Color.clear],
                           center: .bottomTrailing, startRadius: 10, endRadius: 250)

            VStack(spacing: 6) {
                HStack {
                    Button { showProfile = true } label: {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Text(staffMember?.initials ?? "M")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            )
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Circle()
                            .fill(availabilitySwitch ? Color.green : Color.gray)
                            .frame(width: 9, height: 9)
                            .shadow(
                                color: availabilitySwitch ? Color.green.opacity(0.6) : Color.clear,
                                radius: 4
                            )
                            .animation(.easeInOut(duration: 0.3), value: availabilitySwitch)

                        Toggle("", isOn: availabilityBinding)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .labelsHidden()
                            .scaleEffect(0.85)
                            .disabled(isUpdatingAvailability)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 60)

                Text(timeOfDayGreeting)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(0.5)

                Text(headerName.uppercased())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.2)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 50)
            }
        }
        .frame(height: 230)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32,
                topTrailingRadius: 0
            )
        )
    }

    private func activeTaskBanner(_ task: MaintenanceTask) -> some View {
        NavigationLink(value: task) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.appTextPrimary).frame(width: 44, height: 44)
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Task")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                    Text(task.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    let pending = assignedTasks.count + activeTasks.count
                    Text("\(pending) \(pending == 1 ? "Task" : "Tasks") Active")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                    Text(summaryHeadline)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(2).minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [Color.appSurface, Color.appDivider],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 80, height: 70)
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 30))
                        .foregroundColor(.appTextSecondary.opacity(0.4))
                }
            }
            .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 14)

            Rectangle()
                .fill(Color.appDivider.opacity(0.5))
                .frame(height: 1).padding(.horizontal, 22)

            HStack(spacing: 0) {
                statCell(value: assignedTasks.count,  label: "Assigned",    color: .blue)
                Rectangle().fill(Color.appDivider.opacity(0.5)).frame(width: 1, height: 36)
                statCell(value: activeTasks.count,    label: "In Progress", color: .purple)
                Rectangle().fill(Color.appDivider.opacity(0.5)).frame(width: 1, height: 36)
                statCell(value: completedTasks.count, label: "Completed",   color: .green)
            }
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appCardBg)
                .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.appDivider.opacity(0.5), lineWidth: 1)
        )
    }

    private func statCell(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var urgentAlertBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.red.opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.red)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(urgentTasks.count) Urgent \(urgentTasks.count == 1 ? "Task" : "Tasks")")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.red)
                if let first = urgentTasks.first {
                    Text(first.title)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.red.opacity(0.75)).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.red.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.18), lineWidth: 1))
    }

    private var recentTasksSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Active Tasks")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                Spacer()
                let allActive = myTasks.filter { $0.status == .assigned || $0.status == .inProgress }
                if allActive.count > 3 {
                    Text("\(allActive.count - 3) more")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.appOrange)
                }
            }
            .padding(.top, 8)

            ForEach(activePendingTasks) { task in
                NavigationLink(value: task) {
                    TaskCard(task: task, store: store)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 50)).foregroundStyle(.gray.opacity(0.35)).padding(.top, 20)
            Text("All Clear")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            Text("No active tasks right now.\nCheck the Service and Repair tabs for your full task history.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center).lineSpacing(3).padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity).padding(.bottom, 20)
    }

    private var headerName: String {
        staffMember?.displayName ?? user?.name ?? "Technician"
    }

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default:      return "Good Night"
        }
    }

    private var summaryHeadline: String {
        if let a = activeTasks.first   { return "Working on \(a.title)" }
        if let n = assignedTasks.first { return "Up next: \(n.title)" }
        return "All tasks completed"
    }

    private func requestAvailabilityChange(_ available: Bool) {
        guard !isUpdatingAvailability else { return }

        let previous = availabilitySwitch
        availabilitySwitch = available

        Task {
            guard let id = staffMember?.id else {
                await MainActor.run {
                    availabilitySwitch = previous
                    presentToast("Could not update availability", isError: true)
                }
                return
            }

            await MainActor.run { isUpdatingAvailability = true }
            do {
                try await store.updateDriverAvailability(staffId: id, available: available)
                await MainActor.run {
                    isUpdatingAvailability = false
                    presentToast(available ? "You’re Available" : "You’re Offline", isError: false)
                }
            } catch {
                await MainActor.run {
                    isUpdatingAvailability = false
                    availabilitySwitch = previous
                    presentToast("Update failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    private func availabilityToast(message: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(toastIsError ? Color.red.opacity(0.25)
                          : (availabilitySwitch ? Color.green.opacity(0.25) : Color.red.opacity(0.25)))
                    .frame(width: 28, height: 28)
                    .scaleEffect(toastPulseScale)

                Circle()
                    .fill(toastIsError ? Color.red
                          : (availabilitySwitch ? Color.green : Color.red.opacity(0.8)))
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if !toastIsError {
                    Text(availabilitySwitch ? "Ready for new work orders" : "You won’t receive new assignments")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
            }

            Spacer()

            Image(systemName: toastIsError ? "xmark.circle.fill"
                  : (availabilitySwitch ? "checkmark.circle.fill" : "moon.fill"))
                .font(.system(size: 22))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(
                    toastIsError
                        ? Color.red.opacity(0.9)
                        : (availabilitySwitch
                            ? Color.green.opacity(0.9)
                            : Color(red: 0.35, green: 0.35, blue: 0.40))
                )
                .shadow(
                    color: (toastIsError ? Color.red
                            : (availabilitySwitch ? Color.green : Color.black)).opacity(0.3),
                    radius: 16, x: 0, y: 6
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatCount(3, autoreverses: true)
            ) {
                toastPulseScale = 1.5
            }
        }
        .onDisappear {
            toastPulseScale = 1.0
        }
    }

    @MainActor
    private func presentToast(_ message: String, isError: Bool) {
        toastMessage = message
        toastIsError = isError
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { showToast = true }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.35)) { showToast = false }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MaintenanceHomeView()
            .environment(AppDataStore.shared)
    }
}
