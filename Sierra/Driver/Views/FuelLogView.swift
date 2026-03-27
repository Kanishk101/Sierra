import SwiftUI
import PhotosUI

/// Driver fuel-logging form: quantity, cost, odometer, optional receipt photo.
/// Phase 11: Added OCR receipt scanning, auto-calculation, validation warnings.
struct FuelLogView: View {

    @Environment(AppDataStore.self) private var store
    @State private var vm: FuelLogViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showOCRSuccess = false
    @Environment(\.dismiss) private var dismiss

    init(vehicleId: UUID, driverId: UUID, tripId: UUID? = nil) {
        _vm = State(initialValue: FuelLogViewModel(vehicleId: vehicleId, driverId: driverId, tripId: tripId))
    }

    var body: some View {
        NavigationStack {
            Form {
                fuelStatsSection
                fuelDetailsSection
                odometerSection
                receiptSection
                notesSection
            }
            .navigationTitle("Log Fuel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await vm.submit() }
                    }
                    .disabled(vm.isSubmitting || !vm.canSubmit)
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
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    Task { await vm.processReceiptWithOCR(image) }
                }
            }
            .overlay(alignment: .top) {
                if showOCRSuccess {
                    ocrSuccessToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: vm.ocrAutoFilled) { _, filled in
                if filled {
                    withAnimation(.spring(duration: 0.4)) { showOCRSuccess = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { showOCRSuccess = false }
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var vehicleLogs: [FuelLog] {
        store.fuelLogs
            .filter { $0.vehicleId == vm.vehicleId }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    private var fuelStatsSection: some View {
        Section {
            if let last = vehicleLogs.first {
                statRow("Last Fill", value: dateFormatter.string(from: last.loggedAt))
                statRow("Last Qty", value: String(format: "%.1f L", last.fuelQuantityLitres))
                statRow("Last Total", value: "₹\(String(format: "%.0f", last.fuelCost))")
            } else {
                Text("No previous fuel logs for this vehicle yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            let monthly = vehicleLogs.filter { Calendar.current.isDate($0.loggedAt, equalTo: Date(), toGranularity: .month) }
            statRow("This Month Logs", value: "\(monthly.count)")
            statRow("This Month Fuel", value: String(format: "%.1f L", monthly.reduce(0) { $0 + $1.fuelQuantityLitres }))
        } header: {
            Label("Fuel Stats", systemImage: "chart.bar.fill")
        }
    }

    private var fuelDetailsSection: some View {
        Section {
            TextField("Quantity (L)", text: $vm.quantity)
                .keyboardType(.decimalPad)
                .onChange(of: vm.quantity) { _, _ in vm.recalculateTotalCost() }

            TextField("Cost per Litre (₹)", text: $vm.costPerLitre)
                .keyboardType(.decimalPad)
                .onChange(of: vm.costPerLitre) { _, _ in vm.recalculateTotalCost() }

            TextField("Total Cost (₹)", text: $vm.totalCost)
                .keyboardType(.decimalPad)

            // Phase 11: Validation mismatch warning
            if vm.hasTotalCostMismatch {
                Label("Total cost doesn't match quantity × cost per litre",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            TextField("Fuel Station (optional)", text: $vm.fuelStation)
        } header: {
            Label("Fuel Details", systemImage: "fuelpump.fill")
        }
    }

    private var odometerSection: some View {
        Section {
            TextField("Current Reading (km)", text: $vm.odometer)
                .keyboardType(.numberPad)
        } header: {
            Label("Odometer", systemImage: "gauge.with.dots.needle.33percent")
        }
    }

    private var receiptSection: some View {
        Section {
            if vm.isUploadingReceipt {
                HStack {
                    ProgressView()
                    Text("Processing receipt…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if vm.receiptURL != nil {
                Label("Receipt uploaded ✓", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(SierraTheme.Colors.alpineMint)
            }

            // Phase 11: Scan Receipt with Camera + OCR
            Button {
                showCamera = true
            } label: {
                Label("Scan Receipt", systemImage: "doc.text.viewfinder")
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
    }

    private var notesSection: some View {
        Section {
            TextField("Optional notes", text: $vm.notes, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Label("Notes", systemImage: "note.text")
        }
    }

    // MARK: - OCR Success Toast

    private var ocrSuccessToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.white)
            Text("Auto-filled from receipt")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.green.gradient, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.top, 8)
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}
