import SwiftUI


struct StaffReviewSheet: View {
    let application: StaffApplication
    @Bindable var viewModel: StaffApprovalViewModel
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showApproveAlert = false
    @State private var selectedDocs: (title: String, urls: [URL])? = nil

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private var docsCoverBinding: Binding<IdentifiableDocs?> {
        Binding(
            get: { selectedDocs.map { IdentifiableDocs(title: $0.title, urls: $0.urls) } },
            set: { if $0 == nil { selectedDocs = nil } }
        )
    }

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
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Review Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                        await viewModel.approve(applicationId: application.id)
                        // Only dismiss if the operation succeeded (no error set)
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to approve \(store.staffMember(for: application.staffMemberId)?.displayName ?? application.phone)? They will be granted access to Sierra.")
            }
            .animation(.spring(duration: 0.3), value: viewModel.showRejectField)
            .overlay {
                if viewModel.isProcessing {
                    processingOverlay
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unexpected error occurred.")
            }
            .fullScreenCover(item: docsCoverBinding) { docs in
                StaffDocumentViewer(title: docs.title, urls: docs.urls)
            }
        }
    }

    private struct IdentifiableDocs: Identifiable {
        let id = UUID()
        let title: String
        let urls: [URL]
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 64, height: 64)
                .overlay(
                    Text(store.staffMember(for: application.staffMemberId)?.initials ?? String(application.phone.suffix(2)))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                )

            VStack(spacing: 4) {
                Text(store.staffMember(for: application.staffMemberId)?.displayName ?? application.phone)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(store.staffMember(for: application.staffMemberId)?.email ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Label(application.role.displayName, systemImage: application.role == .driver ? "car.fill" : "wrench.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.06), in: Capsule())

                Text("Submitted \(application.daysAgo)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
    }

    // MARK: - Detail Sections

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .padding(.leading, 16)
        }
    }

    private func documentCard(icon: String, title: String, number: String, urlString: String?, expiry: String? = nil) -> some View {
        Button {
            if let urls = deriveDocumentURLs(from: urlString) {
                selectedDocs = (title: title, urls: urls)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                    .frame(width: 38, height: 38)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Text(number)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if let expiry {
                        Text("Expires: \(expiry)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                Image(systemName: urlString != nil ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(urlString != nil ? Color.green.opacity(0.6) : Color.red.opacity(0.6))

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color.clear)
        }
    }

    private func deriveDocumentURLs(from urlString: String?) -> [URL]? {
        guard let urlString = urlString, let url = URL(string: urlString) else { return nil }
        
        // Handle Aadhaar special naming (front/back)
        if urlString.contains("aadhaar-front") {
            let backUrlString = urlString.replacingOccurrences(of: "aadhaar-front", with: "aadhaar-back")
            if let backUrl = URL(string: backUrlString) {
                return [url, backUrl]
            }
        }
        
        // Default to single image if no pattern matched
        return [url]
    }

    // MARK: - Driver Documents

    private var driverDocumentsSection: some View {
        detailSection("Documents") {
            documentCard(icon: "creditcard.fill", title: "Aadhaar Card",
                         number: application.aadhaarNumber,
                         urlString: application.aadhaarDocumentUrl)
            documentCard(icon: "car.fill", title: "Driving License",
                         number: application.driverLicenseNumber ?? "—",
                         urlString: application.driverLicenseDocumentUrl,
                         expiry: application.driverLicenseExpiry)
        }
    }

    // MARK: - Maintenance Documents

    private var maintenanceDocumentsSection: some View {
        VStack(spacing: 16) {
            // Aadhaar
            detailSection("Identity Document") {
                documentCard(icon: "creditcard.fill", title: "Aadhaar Card",
                             number: application.aadhaarNumber,
                             urlString: application.aadhaarDocumentUrl)
            }

            // Certification
            if let certType = application.maintCertificationType {
                detailSection("Technical Certification") {
                    documentCard(icon: "doc.badge.gearshape.fill", title: certType,
                                 number: application.maintCertificationNumber ?? "—",
                                 urlString: application.maintCertificationDocumentUrl,
                                 expiry: application.maintCertificationExpiry)
                    
                    if let auth = application.maintIssuingAuthority {
                        detailRow("Issuing Authority", value: auth)
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
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: 6) {
                                ForEach(specs, id: \.self) { spec in
                                    Text(spec)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.orange.opacity(0.1), in: Capsule())
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

    // MARK: - Rejection

    private func rejectedCard(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.body)
                    .foregroundStyle(.red)
                Text("Rejected")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.red)
            }
            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)

            TextEditor(text: $viewModel.rejectionReason)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.red.opacity(0.3), lineWidth: 1)
                )

            Button {
                Task {
                    await viewModel.reject(applicationId: application.id, reason: viewModel.rejectionReason)
                    // Only dismiss if the operation succeeded (no error set)
                    if viewModel.errorMessage == nil {
                        dismiss()
                    }
                }
            } label: {
                Text("Confirm Rejection")
                    .font(.subheadline)
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

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    viewModel.showRejectField.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("Reject")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.red.opacity(0.4), lineWidth: 1.5)
                )
            }

            Button { showApproveAlert = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("Approve")
                        .font(.system(size: 16, weight: .semibold))
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

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.orange)
                Text("Processing…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .transition(.opacity)
    }
}

private struct StaffDocumentViewer: View {
    let title: String
    let urls: [URL]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if urls.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.text",
                        description: Text("No files are attached for this section.")
                    )
                } else {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        Link(destination: url) {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(.orange)
                                Text("Document \(index + 1)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    StaffReviewSheet(
        application: StaffApplication.samples[0],
        viewModel: StaffApprovalViewModel()
    )
}
