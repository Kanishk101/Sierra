import SwiftUI


struct PendingApprovalsView: View {
    @State private var viewModel = StaffApprovalViewModel()
    @State private var selectedApplication: StaffApplication?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter toggle
                Picker("Filter", selection: $viewModel.selectedFilter) {
                    HStack(spacing: 4) {
                        Text("Pending")
                        if viewModel.pendingCount > 0 {
                            Text("(\(viewModel.pendingCount))")
                        }
                    }.tag(ApprovalStatus.pending)
                    Text("Approved").tag(ApprovalStatus.approved)
                    Text("Rejected").tag(ApprovalStatus.rejected)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // List
                if viewModel.filteredApplications.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredApplications) { app in
                                applicationCard(app)
                                    .onTapGesture {
                                        selectedApplication = app
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle("Staff Applications")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.25), value: viewModel.selectedFilter)
            .sheet(item: $selectedApplication) { app in
                StaffReviewSheet(application: app, viewModel: viewModel)
                    .presentationDetents([.large])
            }
        }
    }

    // MARK: - Application Card

    private func applicationCard(_ app: StaffApplication) -> some View {
        HStack(spacing: 14) {
            initialsCircle(app.initials, size: 48, bg: avatarColor(for: app.status))

            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(SierraFont.body(16, weight: .semibold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)

                HStack(spacing: 8) {
                    roleBadge(app.role)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(app.daysAgo)
                        .font(SierraFont.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if app.status == .pending {
                Text("Review")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.ember)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(SierraTheme.Colors.ember.opacity(0.1), in: Capsule())
            } else {
                statusBadge(app.status)
            }
        }
        .padding(16)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
    }

    // MARK: - Badges

    private func roleBadge(_ role: UserRole) -> some View {
        Text(role.displayName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SierraTheme.Colors.granite)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(SierraTheme.Colors.sierraBlue.opacity(0.06), in: Capsule())
    }

    private func statusBadge(_ status: ApprovalStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .pending:  ("Pending", SierraTheme.Colors.warning)
        case .approved: ("Approved", .green)
        case .rejected: ("Rejected", .red)
        }
        return Text(text)
            .font(SierraFont.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func avatarColor(for status: ApprovalStatus) -> Color {
        switch status {
        case .pending:  SierraTheme.Colors.warning
        case .approved: SierraTheme.Colors.sierraBlue
        case .rejected: SierraTheme.Colors.danger.opacity(0.7)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No \(viewModel.selectedFilter.rawValue.lowercased()) applications")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PendingApprovalsView()
}
