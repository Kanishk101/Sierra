import SwiftUI
import PhotosUI

/// Driver fuel-logging form: quantity, cost, odometer, optional receipt photo.
struct FuelLogView: View {

    @State private var vm: FuelLogViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    init(vehicleId: UUID, driverId: UUID, tripId: UUID? = nil) {
        _vm = State(initialValue: FuelLogViewModel(vehicleId: vehicleId, driverId: driverId, tripId: tripId))
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Fuel Details
                Section {
                    TextField("Quantity (L)", text: $vm.quantity)
                        .keyboardType(.decimalPad)

                    TextField("Cost per Litre (₹)", text: $vm.costPerLitre)
                        .keyboardType(.decimalPad)

                    TextField("Total Cost (₹)", text: $vm.totalCost)
                        .keyboardType(.decimalPad)

                    TextField("Fuel Station (optional)", text: $vm.fuelStation)
                } header: {
                    Label("Fuel Details", systemImage: "fuelpump.fill")
                }

                // MARK: Odometer
                Section {
                    TextField("Current Reading (km)", text: $vm.odometer)
                        .keyboardType(.numberPad)
                } header: {
                    Label("Odometer", systemImage: "gauge.with.dots.needle.33percent")
                }

                // MARK: Receipt
                Section {
                    if vm.isUploadingReceipt {
                        HStack {
                            ProgressView()
                            Text("Uploading receipt…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if vm.receiptURL != nil {
                        Label("Receipt uploaded ✓", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(SierraTheme.Colors.alpineMint)
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(vm.receiptURL == nil ? "Add Receipt Photo" : "Replace Receipt",
                              systemImage: "camera.fill")
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                await vm.uploadReceipt(data)
                            }
                        }
                    }
                } header: {
                    Label("Receipt", systemImage: "doc.text.image")
                }

                // MARK: Notes
                Section {
                    TextField("Optional notes", text: $vm.notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Label("Notes", systemImage: "note.text")
                }
            }
            .navigationTitle("Log Fuel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await vm.submit() }
                    }
                    .disabled(vm.isSubmitting || vm.quantity.isEmpty || vm.totalCost.isEmpty)
                    .fontWeight(.semibold)
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
