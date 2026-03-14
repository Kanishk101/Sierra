import SwiftUI


struct StaffReviewSheet: View {
    let application: StaffApplication
    @Bindable var viewModel: StaffApprovalViewModel
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showApproveAlert = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile header
                        profileHeader

                        // Personal details
                        detailSection("Personal Details") {
                            detailRow("Phone", value: application.phone)
                            detailRow("Date of Birth", value: application.dateOfBirth)
                            detailRow("Gender", value: application.gender)
                            if !application.address.isEmpty {
                                detailRow("Address", value: application.address)
                            }
                            detailRow("Emergency Contact", value: application.emergencyContactName)
                            detailRow("Emergency Phone", value: application.emergencyContactPhone)
                        }

                        // Documents — role-conditional
                        switch application.role {
                        case .driver:
                            driverDocumentsSection
                        case .maintenancePersonnel:
                            maintenanceDocumentsSection
                        default:
                            driverDocumentsSection
                        }

                        // Rejection reason (if rejected)
                        if application.status == .rejected, let reason = application.rejectionReason {
                            rejectedCard(reason: reason)
                        }

                        // Rejection reason input
                        if viewModel.showRejectField {
                            rejectReasonInput
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                // Bottom action bar (only for pending)
                if application.status == .pending {
                    VStack {
                        Spacer()
                        actionBar
                    }
                }
            }
            .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle("Review Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .alert("Approve Application", isPresented: $showApproveAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Approve") {
                    Task {
                        await viewModel.approve(staffId: application.id)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to approve \(store.staffMember(for: application.staffMemberId)?.displayName ?? application.phone)? They will be granted access to FleetOS.")
            }
            .animation(.spring(duration: 0.3), value: viewModel.showRejectField)
            .overlay {
                if viewModel.isProcessing {
                    processingOverlay
                }
            }
        }
    }

    // ─────────────────────────────────
    // MARK: - Profile Header
    // ─────────────────────────────────

    private var profileHeader: some View {
        VStack(spacing: 14) {
            initialsCircle(store.staffMember(for: application.staffMemberId)?.initials ?? String(application.phone.suffix(2)), size: 64, bg: SierraTheme.Colors.ember)

            VStack(spacing: 4) {
                Text(store.staffMember(for: application.staffMemberId)?.displayName ?? application.phone)
                    .font(SierraFont.title3)
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                Text(store.staffMember(for: application.staffMemberId)?.email ?? "")
                    .font(SierraFont.caption1)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Label(application.role.displayName, systemImage: application.role == .driver ? "car.fill" : "wrench.fill")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.granite)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(SierraTheme.Colors.sierraBlue.opacity(0.06), in: Capsule())

                Text("Submitted \(application.daysAgo)")
                    .font(SierraFont.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
    }

    // ─────────────────────────────────
    // MARK: - Detail Sections
    // ─────────────────────────────────

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SierraFont.body(14, weight: .bold))
                .foregroundStyle(SierraTheme.Colors.granite)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                content()
            }
            .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(SierraFont.caption1)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .padding(.leading, 16)
        }
    }

    private func documentCard(icon: String, title: String, number: String, expiry: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(SierraTheme.Colors.ember)
                .frame(width: 38, height: 38)
                .background(SierraTheme.Colors.ember.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                Text(number)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let expiry {
                    Text("Expires: \(expiry)")
                        .font(SierraFont.caption2)
                        .foregroundStyle(SierraTheme.Colors.warning)
                }
            }

            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green.opacity(0.6))
        }
        .padding(14)
    }

    // ─────────────────────────────────
    // MARK: - Driver Documents
    // ─────────────────────────────────

    private var driverDocumentsSection: some View {
        detailSection("Documents") {
            documentCard(icon: "creditcard.fill", title: "Aadhaar Card", number: application.aadhaarNumber)
            documentCard(icon: "car.fill", title: "Driving License",
                         number: application.driverLicenseNumber ?? "—",
                         expiry: application.driverLicenseExpiry)
        }
    }

    // ─────────────────────────────────
    // MARK: - Maintenance Documents
    // ─────────────────────────────────

    private var maintenanceDocumentsSection: some View {
        VStack(spacing: 16) {
            // Aadhaar
            detailSection("Identity Document") {
                documentCard(icon: "creditcard.fill", title: "Aadhaar Card", number: application.aadhaarNumber)
            }

            // Certification
            if let certType = application.maintCertificationType {
                detailSection("Technical Certification") {
                    detailRow("Type", value: certType)
                    if let num = application.maintCertificationNumber {
                        detailRow("Number", value: num)
                    }
                    if let auth = application.maintIssuingAuthority {
                        detailRow("Issuing Authority", value: auth)
                    }
                    if let exp = application.maintCertificationExpiry {
                        detailRow("Expires", value: exp)
                    }
                }
            }

            // Experience
            if let years = application.maintYearsOfExperience {
                detailSection("Work Experience") {
                    detailRow("Years of Experience", value: "\(years) years")
                    if let specs = application.maintSpecializations, !specs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Specializations")
                                .font(SierraFont.caption1)
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: 6) {
                                ForEach(specs, id: \.self) { spec in
                                    Text(spec)
                                        .font(SierraFont.caption2)
                                        .foregroundStyle(SierraTheme.Colors.secondaryText)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(SierraTheme.Colors.ember.opacity(0.1), in: Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    // ─────────────────────────────────
    // MARK: - Rejection
    // ─────────────────────────────────

    private func rejectedCard(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.octagon.fill")
                    .font(SierraFont.bodyText)
                    .foregroundStyle(SierraTheme.Colors.danger)
                Text("Rejected")
                    .font(SierraFont.body(14, weight: .bold))
                    .foregroundStyle(SierraTheme.Colors.danger)
            }
            Text(reason)
                .font(SierraFont.caption1)
                .foregroundStyle(SierraTheme.Colors.secondaryText)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.red.opacity(0.15), lineWidth: 1)
        )
    }

    private var rejectReasonInput: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reason for Rejection")
                .font(SierraFont.body(14, weight: .bold))
                .foregroundStyle(SierraTheme.Colors.primaryText)

            TextEditor(text: $viewModel.rejectionReason)
                .font(SierraFont.subheadline)
                .foregroundStyle(SierraTheme.Colors.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.red.opacity(0.3), lineWidth: 1)
                )

            Button {
                Task {
                    await viewModel.reject(staffId: application.id, reason: viewModel.rejectionReason)
                    dismiss()
                }
            } label: {
                Text("Confirm Rejection")
                    .font(SierraFont.subheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(viewModel.rejectionReason.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(viewModel.rejectionReason.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(16)
        .background(.red.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // ─────────────────────────────────
    // MARK: - Action Bar
    // ─────────────────────────────────

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    viewModel.showRejectField.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(SierraFont.body(14, weight: .bold))
                    Text("Reject")
                        .font(SierraFont.body(16, weight: .semibold))
                }
                .foregroundStyle(SierraTheme.Colors.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.red.opacity(0.4), lineWidth: 1.5)
                )
            }

            Button { showApproveAlert = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(SierraFont.body(14, weight: .bold))
                    Text("Approve")
                        .font(SierraFont.body(16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.white.shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -4)))
    }

    // ─────────────────────────────────
    // MARK: - Processing Overlay
    // ─────────────────────────────────

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(SierraTheme.Colors.ember)
                Text("Processing…")
                    .font(SierraFont.caption1)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .transition(.opacity)
    }
}

#Preview {
    StaffReviewSheet(
        application: StaffApplication.samples[0],
        viewModel: StaffApprovalViewModel()
    )
}
