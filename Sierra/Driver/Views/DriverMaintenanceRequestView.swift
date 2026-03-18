import SwiftUI
import PhotosUI

/// Driver form for raising an ad-hoc maintenance request.
/// Also presented after a failed post-trip inspection.
struct DriverMaintenanceRequestView: View {

    @State private var vm: DriverMaintenanceRequestViewModel
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss

    init(vehicleId: UUID, driverId: UUID, tripId: UUID? = nil, sourceInspectionId: UUID? = nil) {
        _vm = State(initialValue: DriverMaintenanceRequestViewModel(
            vehicleId: vehicleId,
            driverId: driverId,
            tripId: tripId,
            sourceInspectionId: sourceInspectionId
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Issue Details
                Section {
                    TextField("Title (e.g. Brake noise)", text: $vm.title)

                    TextField("Describe the issue", text: $vm.issueDescription, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Label("Issue Details", systemImage: "wrench.and.screwdriver.fill")
                }

                // MARK: Severity
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

                // MARK: Photos
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
                        Label(vm.photos.isEmpty ? "Add Photos" : "Add More Photos",
                              systemImage: "camera.fill")
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
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if vm.isSubmitting {
                        ProgressView()
                    } else {
                        Button("Submit") {
                            Task { await vm.submit() }
                        }
                        .disabled(vm.title.isEmpty || vm.issueDescription.isEmpty)
                        .fontWeight(.semibold)
                    }
                }

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
                if success { dismiss() }
            }
        }
    }
}
