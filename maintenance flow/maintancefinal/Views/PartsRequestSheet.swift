import SwiftUI

struct PartsRequestSheet: View {
    let task: RepairTask
    var onSubmit: ([RequestedPart]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inventoryParts: [RequestedPart]
    @State private var additionalParts: [RequestedPart] = []
    @State private var isSubmitting = false

    private let catalog = RepairStaticData.partsCatalog

    init(task: RepairTask, onSubmit: @escaping ([RequestedPart]) -> Void) {
        self.task = task
        self.onSubmit = onSubmit
        // If no admin-assigned items, give staff one blank row to start filling
        let seed = task.inventoryRequirements.isEmpty
            ? [RequestedPart(name: "", partNumber: "", quantity: 1, reason: "", isFromDropdown: true)]
            : task.inventoryRequirements.map { item in
                RequestedPart(name: item.name, partNumber: item.partNumber, quantity: item.quantity,
                              reason: "", isFromDropdown: true, isAvailable: item.isAvailable)
              }
        _inventoryParts = State(initialValue: seed)
    }

    private var allParts: [RequestedPart] {
        inventoryParts.filter { !$0.name.isEmpty } + additionalParts.filter { !$0.name.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                VStack(spacing: 0) {
                    headerBanner
                    ScrollView {
                        VStack(spacing: 0) {
                            inventorySection
                            additionalSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                    bottomBar
                }
            }
            .navigationTitle("Request Parts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.appOrange)
                }
            }
        }
    }

    // MARK: - Header
    private var headerBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.title3).foregroundStyle(Color.appOrange)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.appTextPrimary)
                Text("Review inventory items and add any additional parts needed.")
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.appOrange.opacity(0.07))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.appOrange.opacity(0.15)), alignment: .bottom)
    }

    // MARK: - Inventory Requirements Section
    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Inventory Requirements", subtitle: "Confirm or adjust items assigned by admin")
            VStack(spacing: 0) {
                ForEach($inventoryParts) { $part in
                    PartInputRow(part: $part, catalog: catalog) {
                        inventoryParts.removeAll { $0.id == part.id }
                    }
                    if part.id != inventoryParts.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
                addRowButton(label: "Add Inventory Item") {
                    inventoryParts.append(RequestedPart(name: "", partNumber: "", quantity: 1, reason: "", isFromDropdown: true))
                }
            }
            .background(Color.appCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }

    // MARK: - Additional Parts Section
    private var additionalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Additional Parts", subtitle: "Extra parts not in the inventory list")
            VStack(spacing: 0) {
                if additionalParts.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.square.dashed").font(.title3)
                            .foregroundStyle(Color.appTextSecondary.opacity(0.45))
                        Text("No additional parts added yet")
                            .font(.subheadline).foregroundStyle(Color.appTextSecondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 18)
                } else {
                    ForEach($additionalParts) { $part in
                        PartInputRow(part: $part, catalog: catalog) {
                            additionalParts.removeAll { $0.id == part.id }
                        }
                        if part.id != additionalParts.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                addRowButton(label: "Add Another Part") {
                    additionalParts.append(RequestedPart(name: "", partNumber: "", quantity: 1, reason: "", isFromDropdown: true))
                }
            }
            .background(Color.appCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .padding(.top, 16)
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        let count = allParts.count
        return Button {
            isSubmitting = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onSubmit(allParts)
                isSubmitting = false
                dismiss()
            }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting { ProgressView().tint(.white).scaleEffect(0.85) }
                Image(systemName: "paperplane.fill")
                Text(count == 0 ? "Submit to Admin" : "Submit \(count) Item\(count == 1 ? "" : "s") to Admin")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                count == 0 ? Color.appTextSecondary.opacity(0.35) : Color.appOrange,
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .disabled(isSubmitting || count == 0)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.appCardBg.shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -2))
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption.weight(.bold)).foregroundStyle(Color.appTextSecondary).kerning(0.8)
            Text(subtitle)
                .font(.caption).foregroundStyle(Color.appTextSecondary.opacity(0.8))
        }
        .padding(.top, 14).padding(.bottom, 8)
    }

    private func addRowButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill").foregroundStyle(Color.appOrange)
                Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Color.appOrange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(Color.appOrange.opacity(0.05))
        }
    }
}

// MARK: - Part Input Row
struct PartInputRow: View {
    @Binding var part: RequestedPart
    let catalog: [String]
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Part name: dropdown OR free-type
            HStack(spacing: 8) {
                partNameField
                Button {
                    part.isFromDropdown.toggle()
                    if part.isFromDropdown { part.name = "" }
                } label: {
                    Image(systemName: part.isFromDropdown ? "pencil.circle" : "list.bullet.circle")
                        .font(.title3).foregroundStyle(Color.appOrange)
                }
                .buttonStyle(.plain)
                .help(part.isFromDropdown ? "Switch to manual entry" : "Switch to catalog")
            }

            // Part number + quantity in one row
            HStack(spacing: 8) {
                Image(systemName: "barcode").font(.caption).foregroundStyle(Color.appTextSecondary)
                TextField("Part no.", text: $part.partNumber)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(maxWidth: 110)
                Divider().frame(height: 18)
                Stepper("Qty: \(part.quantity)", value: $part.quantity, in: 1...99)
                    .font(.caption.weight(.medium)).foregroundStyle(Color.appTextPrimary)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.appDivider, lineWidth: 0.8))

            // Reason
            HStack(spacing: 6) {
                Image(systemName: "text.bubble").font(.caption).foregroundStyle(Color.appTextSecondary)
                TextField("Reason for request (optional)", text: $part.reason)
                    .font(.caption).foregroundStyle(Color.appTextPrimary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.appDivider, lineWidth: 0.8))

            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash").font(.caption).foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    @ViewBuilder
    private var partNameField: some View {
        if part.isFromDropdown {
            Menu {
                ForEach(catalog, id: \.self) { item in
                    Button(item) { part.name = item }
                }
                Divider()
                Button { part.isFromDropdown = false; part.name = "" } label: {
                    Label("Type manually…", systemImage: "pencil")
                }
            } label: {
                HStack {
                    Text(part.name.isEmpty ? "Select part from catalog…" : part.name)
                        .font(.subheadline)
                        .foregroundStyle(part.name.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(Color.appTextSecondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(
                    part.name.isEmpty ? Color.appDivider : Color.appOrange.opacity(0.5), lineWidth: 1))
            }
        } else {
            TextField("Type part name…", text: $part.name)
                .font(.subheadline).foregroundStyle(Color.appTextPrimary)
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.appOrange.opacity(0.5), lineWidth: 1))
        }
    }
}
