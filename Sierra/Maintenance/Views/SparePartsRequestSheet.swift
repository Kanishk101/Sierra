import SwiftUI

// MARK: - SparePartsRequestSheet

struct SparePartsRequestSheet: View {
    let task: MaintenanceTask
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var requiredParts: [DraftPart] = [DraftPart()]
    @State private var additionalParts: [DraftPart] = []
    @State private var isSubmitting = false
    @State private var showSuccess = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }
    private var workOrder: WorkOrder? { store.workOrder(forMaintenanceTask: task.id) }
    private var catalogParts: [InventoryPart] {
        store.inventoryParts
            .filter(\.isActive)
            .sorted { $0.partName.localizedCaseInsensitiveCompare($1.partName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerBanner
                    requiredPartsSection
                    additionalPartsSection
                    Spacer(minLength: 100)
                }
            }
            .background(Color.appSurface.ignoresSafeArea())
            .navigationTitle("Request Parts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.appOrange)
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .overlay {
                if showSuccess {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 14) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(SierraFont.scaled(56))
                                .foregroundStyle(.green)
                            Text("Parts Requested!")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appTextPrimary)
                            Text("Admin will review your request.")
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(32)
                        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.15), radius: 20)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showSuccess)
            .task {
                if store.inventoryParts.isEmpty {
                    await store.loadMaintenanceData(staffId: currentUserId)
                }
            }
        }
    }

    // MARK: - Header

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "wrench.fill")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.appOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("Add parts required for this repair")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                statCapsule(title: "Required", value: requiredParts.count, tint: .appOrange)
                statCapsule(title: "Additional", value: additionalParts.count, tint: .blue)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appOrange.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appOrange.opacity(0.18), lineWidth: 1))
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Required Parts Section

    private var requiredPartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("INVENTORY REQUIREMENTS", systemImage: "shippingbox")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .kerning(0.8)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        requiredParts.append(DraftPart())
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.appOrange)
                }
            }
            ForEach(requiredParts.indices, id: \.self) { idx in
                PartInputRow(
                    part: $requiredParts[idx],
                    catalogParts: catalogParts,
                    canRemove: requiredParts.count > 1,
                    onRemove: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            _ = requiredParts.remove(at: idx)
                        }
                    }
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appCardBg)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.45), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Additional Parts

    private var additionalPartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ADDITIONAL PARTS", systemImage: "plus.square.on.square")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .kerning(0.8)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        additionalParts.append(DraftPart())
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.caption)
                        Text("Add Part").font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.appOrange.opacity(0.1), in: Capsule())
                }
            }
            if additionalParts.isEmpty {
                HStack {
                    Spacer()
                    Text("No additional parts added")
                        .font(.caption).foregroundStyle(Color.appTextSecondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(additionalParts.indices, id: \.self) { idx in
                    PartInputRow(
                        part: $additionalParts[idx],
                        catalogParts: catalogParts,
                        canRemove: true,
                        onRemove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                _ = additionalParts.remove(at: idx)
                            }
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appCardBg)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.45), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Bottom Submit Bar

    private var bottomBar: some View {
        let allParts = requiredParts + additionalParts
        let validParts = allParts.filter { !$0.partName.trimmingCharacters(in: .whitespaces).isEmpty }

        return VStack(spacing: 0) {
            Divider()
            Button {
                Task { await submitParts(validParts) }
            } label: {
                HStack(spacing: 10) {
                    if isSubmitting { ProgressView().tint(.white).scaleEffect(0.85) }
                    Image(systemName: "paperplane.fill")
                    Text("Submit \(validParts.count) Part\(validParts.count == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    validParts.isEmpty ? Color.gray.opacity(0.3) : Color.appOrange,
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .disabled(validParts.isEmpty || isSubmitting)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }

    private func statCapsule(title: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(SierraFont.scaled(11, weight: .bold, design: .rounded))
            Text(title)
                .font(SierraFont.scaled(10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
    }

    // MARK: - Submit

    private func submitParts(_ parts: [DraftPart]) async {
        isSubmitting = true

        for part in parts {
            let request = SparePartsRequest(
                id: UUID(),
                maintenanceTaskId: task.id,
                workOrderId: workOrder?.id,
                requestedById: currentUserId,
                partName: part.partName,
                partNumber: part.partNumber.isEmpty ? nil : part.partNumber,
                quantity: part.quantity,
                estimatedUnitCost: nil,
                supplier: nil,
                reason: part.reason.isEmpty ? "Required for repair" : part.reason,
                status: .pending,
                quantityAvailable: 0,
                quantityAllocated: 0,
                quantityOnOrder: 0,
                createdAt: Date(),
                updatedAt: Date()
            )
            try? await store.addSparePartsRequest(request)
        }

        // Mark work order parts status to requested
        if let wo = workOrder, wo.partsSubStatus == .none {
            try? await WorkOrderService.updatePartsSubStatus(workOrderId: wo.id, status: .requested)
            if let idx = store.workOrders.firstIndex(where: { $0.id == wo.id }) {
                store.workOrders[idx].partsSubStatus = .requested
            }
        }

        isSubmitting = false

        // Show success confirmation
        withAnimation { showSuccess = true }
        try? await Task.sleep(for: .seconds(1.5))
        dismiss()
    }
}

// MARK: - Draft Part Model

struct DraftPart: Identifiable {
    let id = UUID()
    var partName: String = ""
    var partNumber: String = ""
    var quantity: Int = 1
    var reason: String = ""
    var useCatalog: Bool = true
}

// MARK: - Part Input Row

struct PartInputRow: View {
    @Binding var part: DraftPart
    var catalogParts: [InventoryPart]
    var canRemove: Bool
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Toggle catalog / free-text
                Picker("Mode", selection: $part.useCatalog) {
                    Text("Catalog").tag(true)
                    Text("Custom").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Spacer()
                if canRemove {
                    Button(action: onRemove) {
                        Image(systemName: "trash.fill")
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
            }

            if part.useCatalog {
                // Catalog dropdown
                Menu {
                    ForEach(catalogParts, id: \.id) { item in
                        Button {
                            part.partName = item.partName
                            part.partNumber = item.partNumber ?? ""
                        } label: {
                            HStack {
                                Text(item.partName)
                                Spacer()
                                Text(item.partNumber ?? "No PN").foregroundStyle(.secondary)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(
                            part.partName.isEmpty
                            ? (catalogParts.isEmpty ? "No parts available" : "Select Part…")
                            : part.partName
                        )
                            .font(.subheadline)
                            .foregroundStyle(part.partName.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.down").font(.caption).foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
                }
                .disabled(catalogParts.isEmpty)
            } else {
                TextField("Part Name", text: $part.partName)
                    .textFieldStyle(.customRounded)
                TextField("Part Number (optional)", text: $part.partNumber)
                    .textFieldStyle(.customRounded)
            }

            // Quantity
            HStack {
                Text("Qty").font(.caption.weight(.medium)).foregroundStyle(Color.appTextSecondary)
                Spacer()
                HStack(spacing: 10) {
                    qtyButton(icon: "minus") { part.quantity = max(1, part.quantity - 1) }
                    Text("\(part.quantity)")
                        .font(SierraFont.scaled(18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                        .frame(minWidth: 26)
                    qtyButton(icon: "plus") { part.quantity = min(99, part.quantity + 1) }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.appCardBg))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appDivider.opacity(0.6), lineWidth: 1))
            }

            // Reason
            TextField("Reason / notes", text: $part.reason)
                .textFieldStyle(.customRounded)
        }
        .padding(12)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appDivider.opacity(0.5), lineWidth: 1))
    }

    private func qtyButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(SierraFont.scaled(12, weight: .bold))
                .foregroundStyle(Color.appTextPrimary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.appSurface))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom TextField Style

struct CustomRoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider, lineWidth: 0.5))
    }
}

extension TextFieldStyle where Self == CustomRoundedTextFieldStyle {
    static var customRounded: Self { CustomRoundedTextFieldStyle() }
}
