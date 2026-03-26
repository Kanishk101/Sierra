import SwiftUI
import PhotosUI

/// Driver form for raising an ad-hoc maintenance request.
/// Also presented after a failed post-trip inspection.
struct DriverMaintenanceRequestView: View {

    @State private var vm: DriverMaintenanceRequestViewModel
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss
    private let onSubmitted: (() -> Void)?

    init(
        vehicleId: UUID,
        driverId: UUID,
        tripId: UUID? = nil,
        sourceInspectionId: UUID? = nil,
        initialTitle: String = "",
        initialDescription: String = "",
        lockCoreFields: Bool = false,
        fixedTripDisplayId: String? = nil,
        fixedIssueSummary: String? = nil,
        showsSeverityPicker: Bool = true,
        onSubmitted: (() -> Void)? = nil
    ) {
        _vm = State(initialValue: DriverMaintenanceRequestViewModel(
            vehicleId: vehicleId,
            driverId: driverId,
            tripId: tripId,
            sourceInspectionId: sourceInspectionId,
            initialTitle: initialTitle,
            initialDescription: initialDescription,
            lockCoreFields: lockCoreFields,
            fixedTripDisplayId: fixedTripDisplayId,
            fixedIssueSummary: fixedIssueSummary,
            showsSeverityPicker: showsSeverityPicker
        ))
        self.onSubmitted = onSubmitted
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.lockCoreFields {
                    lockedPostTripLayout
                } else {
                    defaultFormLayout
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(vm.submitError != nil)) {
                Button("OK") { vm.submitError = nil }
            } message: {
                Text(vm.submitError ?? "")
            }
            .onChange(of: vm.submitSuccess) { _, success in
                if success {
                    onSubmitted?()
                    dismiss()
                }
            }
        }
    }

    private var defaultFormLayout: some View {
        Form {
            Section {
                TextField("Title (e.g. Brake noise)", text: $vm.title)

                TextField("Describe the issue", text: $vm.issueDescription, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Label("Issue Details", systemImage: "wrench.and.screwdriver.fill")
            }

            if vm.showsSeverityPicker {
                Section {
                    Picker("Priority", selection: $vm.priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("Severity", systemImage: "exclamationmark.triangle.fill")
                }
            }

            photoSection

            Section {
                submitButton
            }
            .listRowBackground(Color.clear)
        }
    }

    private var lockedPostTripLayout: some View {
        ZStack {
            Color.appSurface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundStyle(Color.appOrange)
                            Text("Post-Trip Defect")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appTextPrimary)
                        }

                        Text("Submit this request and continue post-trip inspection.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.appCardBg))

                    lockedInfoRow(label: "Defect Type", value: vm.title)

                    if let tripCode = vm.fixedTripDisplayId, !tripCode.isEmpty {
                        lockedInfoRow(label: "Trip ID", value: tripCode)
                    }

                    if let issue = vm.fixedIssueSummary, !issue.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Issue Found")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.appTextSecondary)

                            Text(issue)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appOrange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.appOrange.opacity(0.12)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appOrange.opacity(0.35), lineWidth: 1)
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.appCardBg))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)

                        TextEditor(text: $vm.issueDescription)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.appTextPrimary)
                            .frame(minHeight: 120)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.appDivider, lineWidth: 1)
                            )

                        Text("Add any extra notes for admin (optional).")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.appCardBg))

                    photosCard

                    submitButton
                        .padding(.top, 6)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
    }

    private func lockedInfoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.appOrange)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.appSurface))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appDivider, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.appCardBg))
    }

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Optional Photos", systemImage: "photo.on.rectangle.angled")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)

            if !vm.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.photos.indices, id: \.self) { idx in
                            if let uiImage = UIImage(data: vm.photos[idx]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                Label(vm.photos.isEmpty ? "Add Photos" : "Add More Photos", systemImage: "camera.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appOrange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appOrange.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appOrange.opacity(0.28), lineWidth: 1.2)
                    )
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            vm.photos.append(data)
                        }
                    }
                    selectedPhotos = []
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.appCardBg))
    }

    private var photoSection: some View {
        Section {
            if !vm.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.photos.indices, id: \.self) { idx in
                            if let uiImage = UIImage(data: vm.photos[idx]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                Label(vm.photos.isEmpty ? "Add Photos" : "Add More Photos", systemImage: "camera.fill")
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            vm.photos.append(data)
                        }
                    }
                    selectedPhotos = []
                }
            }
        } header: {
            Label("Photos", systemImage: "photo.on.rectangle.angled")
        }
    }

    private var submitButton: some View {
        Button {
            Task { await vm.submit() }
        } label: {
            HStack(spacing: 8) {
                if vm.isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                }
                Text("Submit Request")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(vm.isSubmitting ? Color.appOrange.opacity(0.6) : Color.appOrange)
            )
            .shadow(color: Color.appOrange.opacity(0.28), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(vm.isSubmitting || vm.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
