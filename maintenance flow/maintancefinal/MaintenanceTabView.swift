import SwiftUI

struct MaintenanceTabView: View {

    init() {
        MaintenanceTheme.configureTabBar()
    }

    var body: some View {
        TabView {
            Tab("Repair", systemImage: "wrench.and.screwdriver.fill") {
                RepairTaskListView()
            }
            Tab("Service", systemImage: "calendar.badge.checkmark") {
                ServiceTaskListView()
            }
            Tab("Profile", systemImage: "person.crop.circle.fill") {
                ProfileTabView()
            }
        }
        .tint(Color.appOrange)
    }
}

// MARK: - Profile Tab

struct ProfileTabView: View {
    @State private var vm = ProfileEditViewModel()
    @State private var showEditSheet = false
    @State private var showNotifications = false

    private var repairTasks: [RepairTask]  { RepairStaticData.repairTasks }
    private var serviceTasks: [ServiceTask] { RepairStaticData.serviceTasks }

    private var completedCount: Int { repairTasks.filter { $0.status == .repairDone }.count }
    private var inProgressCount: Int { repairTasks.filter { $0.status == .underMaintenance || $0.status == .partsRequested || $0.status == .partsReady }.count }
    private var totalCount: Int { repairTasks.count }
    private var notifCount: Int { repairTasks.filter { $0.status == .partsReady }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        profileHeader
                        statsRow
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                        infoSection
                            .padding(.top, 16)
                        specialisationsSection
                            .padding(.top, 16)
                        recentActivitySection
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Notifications bell
                        Button { showNotifications = true } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .foregroundStyle(Color.appOrange)
                                    .font(.system(size: 18))
                                if notifCount > 0 {
                                    Circle().fill(.red).frame(width: 14, height: 14)
                                        .overlay(Text("\(notifCount)").font(.system(size: 8, weight: .bold)).foregroundStyle(.white))
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                        // Edit
                        Button { showEditSheet = true } label: {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(Color.appOrange)
                                .font(.system(size: 20))
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                ProfileEditSheet(vm: vm)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsSheet(tasks: repairTasks)
            }
        }
    }

    // MARK: - Header
    private var profileHeader: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color.appOrange, Color.appDeepOrange],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 180)

            VStack(spacing: 10) {
                // Avatar
                Circle()
                    .fill(.white.opacity(0.22))
                    .frame(width: 86, height: 86)
                    .overlay(
                        Text(String(vm.name.prefix(2)).uppercased())
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    )
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.5), lineWidth: 2)
                    )

                VStack(spacing: 4) {
                    Text(vm.name)
                        .font(.title3.weight(.bold)).foregroundStyle(.white)
                    Text(vm.email)
                        .font(.caption).foregroundStyle(.white.opacity(0.85))
                    // Role badge
                    Text(StaticData.userProfile.role)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .background(.white.opacity(0.18), in: Capsule())

                    // Approved badge
                    if StaticData.userProfile.isApproved {
                        Label("Verified Staff", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.top, 24)
        }
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 28,
            bottomTrailingRadius: 28, topTrailingRadius: 0, style: .continuous
        ))
    }

    // MARK: - Stats
    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: "\(completedCount)", label: "Completed",
                     icon: "checkmark.circle.fill", color: .green)
            Divider().frame(height: 44)
            statCell(value: "\(inProgressCount)", label: "In Progress",
                     icon: "wrench.fill", color: .purple)
            Divider().frame(height: 44)
            statCell(value: "\(totalCount)", label: "Total Tasks",
                     icon: "list.clipboard.fill", color: Color.appOrange)
        }
        .padding(.vertical, 14)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(Color.appTextPrimary)
            Text(label).font(.system(size: 10)).foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader("Personal Information", icon: "person.text.rectangle.fill")
            Divider()
            infoRow(icon: "person.fill", label: "Full Name", value: vm.name)
            Divider().padding(.leading, 52)
            infoRow(icon: "envelope.fill", label: "Email", value: vm.email)
            Divider().padding(.leading, 52)
            infoRow(icon: "phone.fill", label: "Phone", value: vm.phone)
            Divider().padding(.leading, 52)
            infoRow(icon: "calendar", label: "Date of Birth", value: vm.dateOfBirth)
            Divider().padding(.leading, 52)
            infoRow(icon: "creditcard.fill", label: "Aadhaar", value: vm.aadhaarNumber)
            Divider().padding(.leading, 52)
            infoRow(icon: "briefcase.fill", label: "Experience", value: "\(StaticData.userProfile.yearsOfExperience) years")
            Divider().padding(.leading, 52)
            infoRow(icon: "rosette", label: "Certification", value: StaticData.userProfile.certificationType)
            Divider().padding(.leading, 52)
            infoRow(icon: "calendar.badge.clock", label: "Cert. Expiry", value: StaticData.userProfile.certificationExpiry)
        }
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appOrange.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appOrange)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Specialisations
    private var specialisationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader("Specialisations", icon: "star.fill")
            Divider()
            FlowLayout(spacing: 8) {
                ForEach(StaticData.userProfile.specializations, id: \.self) { spec in
                    Text(spec)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.appOrange)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.appOrange.opacity(0.1), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.appOrange.opacity(0.25), lineWidth: 0.8))
                }
            }
            .padding(16)
        }
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Recent Activity
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader("Recent Repair Activity", icon: "clock.arrow.circlepath")
            Divider()
            if repairTasks.isEmpty {
                Text("No activity yet")
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
                    .padding(16)
            } else {
                ForEach(repairTasks.prefix(4)) { task in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(task.status.color.opacity(0.12)).frame(width: 36, height: 36)
                            Image(systemName: task.status.icon).font(.system(size: 14)).foregroundStyle(task.status.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title).font(.subheadline.weight(.medium)).foregroundStyle(Color.appTextPrimary)
                            Text(task.status.rawValue).font(.caption).foregroundStyle(task.status.color)
                        }
                        Spacer()
                        Text(task.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption2).foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    if task.id != repairTasks.prefix(4).last?.id { Divider().padding(.leading, 64) }
                }
            }
        }
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private func cardHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Color.appOrange)
            Text(title.uppercased())
                .font(.caption.weight(.bold)).foregroundStyle(Color.appTextSecondary).kerning(0.6)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }
}

// MARK: - Profile Edit Sheet

struct ProfileEditSheet: View {
    @Bindable var vm: ProfileEditViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Avatar preview
                        Circle()
                            .fill(Color.appOrange.opacity(0.12))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(vm.name.prefix(2)).uppercased())
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.appOrange)
                            )
                            .overlay(Circle().strokeBorder(Color.appOrange.opacity(0.3), lineWidth: 2))
                            .padding(.top, 20)

                        editCard("Personal Details") {
                            editField("Full Name", icon: "person.fill", text: $vm.name)
                            Divider().padding(.leading, 52)
                            editField("Email", icon: "envelope.fill", text: $vm.email, keyboard: .emailAddress)
                            Divider().padding(.leading, 52)
                            editField("Phone", icon: "phone.fill", text: $vm.phone, keyboard: .phonePad)
                        }

                        editCard("Personal Info") {
                            editField("Date of Birth", icon: "calendar", text: $vm.dateOfBirth, placeholder: "e.g. 12 Aug 1990")
                            Divider().padding(.leading, 52)
                            editField("Aadhaar Number", icon: "creditcard.fill", text: $vm.aadhaarNumber, keyboard: .numberPad)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.appOrange)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.save()
                        dismiss()
                    }
                    .fontWeight(.semibold).foregroundStyle(Color.appOrange)
                }
            }
        }
    }

    private func editCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.caption.weight(.bold)).foregroundStyle(Color.appTextSecondary).kerning(0.6)
                .padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            content()
        }
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func editField(_ label: String, icon: String, text: Binding<String>,
                           placeholder: String? = nil, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.appOrange.opacity(0.1)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(Color.appOrange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(Color.appTextSecondary)
                TextField(placeholder ?? label, text: text)
                    .font(.subheadline).foregroundStyle(Color.appTextPrimary)
                    .keyboardType(keyboard)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// MARK: - Notifications Sheet

struct NotificationsSheet: View {
    let tasks: [RepairTask]
    @Environment(\.dismiss) private var dismiss

    private var partsReadyTasks: [RepairTask] { tasks.filter { $0.status == .partsReady } }
    private var overdueTasks: [RepairTask] { tasks.filter {
        guard $0.status == .underMaintenance,
              let started = $0.startedAt,
              let eta = $0.estimatedMinutes else { return false }
        return started.addingTimeInterval(Double(eta * 60)) < Date()
    }}
    private var allNotifs: [(task: RepairTask, type: NotifType)] {
        partsReadyTasks.map { ($0, .partsReady) } + overdueTasks.map { ($0, .overdue) }
    }

    enum NotifType { case partsReady, overdue }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                if allNotifs.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.appOrange.opacity(0.3))
                        Text("No notifications")
                            .font(.subheadline).foregroundStyle(Color.appTextSecondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(allNotifs, id: \.task.id) { item in
                                notifCard(task: item.task, type: item.type)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appOrange)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func notifCard(task: RepairTask, type: NotifType) -> some View {
        let (icon, color, headline, sub): (String, Color, String, String) = {
            switch type {
            case .partsReady:
                return ("checkmark.circle.fill", Color(red: 0.1, green: 0.7, blue: 0.4),
                        "Parts Ready – \(task.title)",
                        "All parts available. Tap to start work.")
            case .overdue:
                return ("exclamationmark.triangle.fill", .red,
                        "Overdue – \(task.title)",
                        "Estimated completion time has passed.")
            }
        }()
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 42, height: 42)
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(headline).font(.subheadline.weight(.semibold)).foregroundStyle(Color.appTextPrimary)
                Text(sub).font(.caption).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Color.appTextSecondary)
        }
        .padding(14)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Profile Edit ViewModel

@Observable
final class ProfileEditViewModel {
    var name: String = StaticData.userProfile.name
    var email: String = StaticData.userProfile.email
    var phone: String = StaticData.userProfile.phone
    var dateOfBirth: String = StaticData.userProfile.dateOfBirth
    var aadhaarNumber: String = StaticData.userProfile.aadhaarNumber

    func save() {
        // In a real app: persist to SwiftData / UserDefaults
    }
}

// MARK: - Flow Layout helper (wrapping HStack for chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxY: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            maxY = y + rowH
        }
        return CGSize(width: width, height: maxY)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        var rowViews: [(Subviews.Element, CGSize)] = []
        func placeRow() {
            var rx = x
            for (v, s) in rowViews { v.place(at: CGPoint(x: rx, y: y), proposal: .unspecified); rx += s.width + spacing }
            y += rowH + spacing; rowH = 0; rowViews.removeAll()
        }
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, !rowViews.isEmpty { placeRow(); x = bounds.minX }
            rowViews.append((v, s)); x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        if !rowViews.isEmpty { placeRow() }
    }
}

#Preview { MaintenanceTabView() }
