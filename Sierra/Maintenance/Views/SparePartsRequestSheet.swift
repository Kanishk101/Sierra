import SwiftUI

/// Sheet for requesting spare parts for a maintenance task.
struct SparePartsRequestSheet: View {

    let maintenanceTaskId: UUID
    let workOrderId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var partName = ""
    @State private var partNumber = ""
    @State private var quantity = 1
    @State private var estimatedCost: Double?
    @State private var supplier = ""
    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var existingRequests: [SparePartsRequest] = []
    @State private var errorMessage: String?
    @State private var showError = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    var body: some View {
        NavigationStack {
            List {
                // New request form
                Section("New Request") {
                    TextField("Part Name *", text: $partName)
                    TextField("Part Number", text: $partNumber)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...100)
                    HStack {
                        Text("Est. Unit Cost")
                        Spacer()
                        TextField("₹", value: $estimatedCost, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    TextField("Supplier", text: $supplier)
                    TextField("Reason *", text: $reason)
                }

                Section {
                    Button {
                        Task { await submitRequest() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting { ProgressView().tint(.white) }
                            Text("Submit Request")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .listRowBackground(canSubmit ? SierraTheme.Colors.ember : Color.gray)
                    }
                    .disabled(!canSubmit || isSubmitting)
                }

                // Existing requests
                if !existingRequests.isEmpty {
                    Section("Existing Requests") {
                        ForEach(existingRequests) { req in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(req.partName).font(.subheadline.weight(.medium))
                                    Spacer()
                                    statusBadge(req.status)
                                }
                                HStack(spacing: 12) {
                                    Text("Qty: \(req.quantity)").font(.caption)
                                    if let cost = req.estimatedUnitCost {
                                        Text("₹\(cost, specifier: "%.2f")").font(.caption)
                                    }
                                    Text(req.reason).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Spare Parts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                do {
                    existingRequests = try await SparePartsRequestService.fetchRequests(for: maintenanceTaskId)
                } catch {
                    print("[SpareParts] Fetch error: \(error)")
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Something went wrong")
            }
        }
    }

    private var canSubmit: Bool {
        !partName.trimmingCharacters(in: .whitespaces).isEmpty
        && !reason.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submitRequest() async {
        isSubmitting = true
        do {
            try await SparePartsRequestService.submitRequest(
                maintenanceTaskId: maintenanceTaskId,
                workOrderId: workOrderId,
                requestedById: currentUserId,
                partName: partName,
                partNumber: partNumber.isEmpty ? nil : partNumber,
                quantity: quantity,
                estimatedUnitCost: estimatedCost,
                supplier: supplier.isEmpty ? nil : supplier,
                reason: reason
            )
            // Refresh list
            existingRequests = try await SparePartsRequestService.fetchRequests(for: maintenanceTaskId)
            // Clear form
            partName = ""; partNumber = ""; quantity = 1; estimatedCost = nil; supplier = ""; reason = ""
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSubmitting = false
    }

    private func statusBadge(_ status: SparePartsRequestStatus) -> some View {
        Text(status.rawValue)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(statusColor(status), in: Capsule())
    }

    private func statusColor(_ s: SparePartsRequestStatus) -> Color {
        switch s {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        case .fulfilled: return .blue
        }
    }
}
