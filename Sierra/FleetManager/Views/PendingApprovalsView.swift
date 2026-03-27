import SwiftUI


struct PendingApprovalsView: View {
    @Environment(AppDataStore.self) private var store
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
                .background(Color.appSurface)

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
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel("Open \(app.role.displayName) application")
                                    .accessibilityHint("Shows application details and actions")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color.appSurface.ignoresSafeArea())
            .navigationTitle("Staff Applications")
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.25), value: viewModel.selectedFilter)
            .sheet(item: $selectedApplication) { app in
                StaffReviewSheet(application: app, viewModel: viewModel)
                    .presentationDetents([.large])
            }
        }
    }

    // MARK: - Application Card

    private func applicantName(_ app: StaffApplication) -> String {
        store.staffMember(for: app.staffMemberId)?.displayName ?? app.phone
    }

    private func applicantInitials(_ app: StaffApplication) -> String {
        store.staffMember(for: app.staffMemberId)?.initials ?? String(app.phone.suffix(2))
    }

    private func applicationCard(_ app: StaffApplication) -> some View {
        HStack(spacing: 14) {
            initialsCircle(applicantInitials(app), size: 48, bg: avatarColor(for: app.status))

            VStack(alignment: .leading, spacing: 4) {
                Text(applicantName(app))
                    .font(SierraFont.scaled(16, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    roleBadge(app.role)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(app.daysAgo)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if app.status == .pending {
                Text("Review")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.1), in: Capsule())
            } else {
                statusBadge(app.status)
            }
        }
        .padding(16)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appDivider.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    // MARK: - Badges

    private func roleBadge(_ role: UserRole) -> some View {
        Text(role.displayName)
            .font(SierraFont.scaled(11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.06), in: Capsule())
    }

    private func statusBadge(_ status: ApprovalStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .pending:  ("Pending", .orange)
        case .approved: ("Approved", .green)
        case .rejected: ("Rejected", .red)
        }
        return Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func avatarColor(for status: ApprovalStatus) -> Color {
        switch status {
        case .pending:  .orange
        case .approved: .blue
        case .rejected: .red.opacity(0.7)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(SierraFont.scaled(48, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No \(viewModel.selectedFilter.rawValue.lowercased()) applications")
                .font(SierraFont.scaled(16, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PendingApprovalsView()
}
