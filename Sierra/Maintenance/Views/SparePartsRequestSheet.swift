import SwiftUI

// MARK: - SparePartsRequestSheet

struct SparePartsRequestSheet: View {
    let task: MaintenanceTask
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var requiredParts: [DraftPart] = [DraftPart()]
    @State private var additionalParts: [DraftPart] = []
    @State private var isSubmitting = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }
    private var workOrder: WorkOrder? { store.workOrder(forMaintenanceTask: task.id) }

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
        }
    }

    // MARK: - Header

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        }
        .padding(16)
        .background(Color.appOrange.opacity(0.06))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Required Parts Section

    @ViewBuilder
    private var requiredPartsSection: some View {
        let sectionContent = VStack(alignment: .leading, spacing: 12) {
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
                    canRemove: requiredParts.count > 1,
                    onRemove: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            _ = requiredParts.remove(at: idx)
                        }
                    }
                )
            }
        }
        sectionContent
            .padding(16)
            .background(Color.appCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            .padding(.horizontal, 16)
            .padding(.top, 12)
    }

    // MARK: - Additional Parts

    @ViewBuilder
    private var additionalPartsSection: some View {
        let sectionContent = VStack(alignment: .leading, spacing: 12) {
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
        sectionContent
            .padding(16)
            .background(Color.appCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
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

    // MARK: - Submit

    private func submitParts(_ parts: [DraftPart]) async {
        isSubmitting = true
        defer { isSubmitting = false }

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
        if var wo = workOrder, wo.partsSubStatus == .none {
            wo.partsSubStatus = .requested
            try? await store.updateWorkOrder(wo)
        }

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
                    ForEach(PartsCatalog.items, id: \.name) { item in
                        Button {
                            part.partName = item.name
                            part.partNumber = item.partNumber
                        } label: {
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text(item.partNumber).foregroundStyle(.secondary)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(part.partName.isEmpty ? "Select Part…" : part.partName)
                            .font(.subheadline)
                            .foregroundStyle(part.partName.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.down").font(.caption).foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
                }
            } else {
                TextField("Part Name", text: $part.partName)
                    .textFieldStyle(.customRounded)
                TextField("Part Number (optional)", text: $part.partNumber)
                    .textFieldStyle(.customRounded)
            }

            // Quantity
            HStack {
                Text("Qty").font(.caption.weight(.medium)).foregroundStyle(Color.appTextSecondary)
                Stepper("\(part.quantity)", value: $part.quantity, in: 1...99)
                    .labelsHidden()
                Text("\(part.quantity)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                    .padding(.horizontal, 8)
            }

            // Reason
            TextField("Reason / notes", text: $part.reason)
                .textFieldStyle(.customRounded)
        }
        .padding(12)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

// MARK: - Parts Catalog (Static Data)

enum PartsCatalog {
    struct CatalogItem {
        let name: String
        let partNumber: String
    }

    static let items: [CatalogItem] = [
        .init(name: "Brake Pad Set – Front", partNumber: "BP-F-001"),
        .init(name: "Brake Pad Set – Rear", partNumber: "BP-R-002"),
        .init(name: "Oil Filter", partNumber: "OF-STD-010"),
        .init(name: "Air Filter (Engine)", partNumber: "AF-ENG-020"),
        .init(name: "Cabin Air Filter", partNumber: "AF-CAB-021"),
        .init(name: "Spark Plug (pack of 4)", partNumber: "SP-STD-030"),
        .init(name: "Battery (12V 70Ah)", partNumber: "BAT-12V-070"),
        .init(name: "Wiper Blade (pair)", partNumber: "WB-STD-040"),
        .init(name: "Headlight Bulb (LED)", partNumber: "HL-LED-050"),
        .init(name: "Tyre – Front (205/55 R16)", partNumber: "TY-F-205"),
        .init(name: "Tyre – Rear (205/55 R16)", partNumber: "TY-R-205"),
        .init(name: "Engine Oil (5W-30, 5L)", partNumber: "LUB-5W30-5L"),
        .init(name: "Coolant Top-Up (1L)", partNumber: "LUB-COOL-1L"),
        .init(name: "Transmission Fluid (1L)", partNumber: "LUB-TRANS-1L"),
        .init(name: "Timing Belt", partNumber: "TB-STD-060"),
        .init(name: "Serpentine Belt", partNumber: "SB-STD-070"),
        .init(name: "Alternator", partNumber: "ALT-STD-080"),
        .init(name: "Starter Motor", partNumber: "STR-STD-090"),
        .init(name: "Radiator Hose (upper)", partNumber: "RH-UPR-100"),
        .init(name: "Windscreen (laminated)", partNumber: "WS-LAM-110"),
    ]
}
