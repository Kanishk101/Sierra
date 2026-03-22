import SwiftUI

// MARK: - FilterOption

struct FilterOption: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String?
    let color: Color?

    init(id: String, label: String, icon: String? = nil, color: Color? = nil) {
        self.id    = id
        self.label = label
        self.icon  = icon
        self.color = color
    }
}

// MARK: - FilterSheetView
// Reusable filter sheet (Phase 9). Half-sheet with radio-style checkmark list.
// Used by VehicleListView and TripsListView.

struct FilterSheetView: View {

    let title: String
    let options: [FilterOption]
    @Binding var selectedId: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // "All" option
                filterRow(FilterOption(id: "all", label: "All", icon: nil, color: nil))
                ForEach(options) { option in
                    filterRow(option)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func filterRow(_ option: FilterOption) -> some View {
        Button {
            selectedId = option.id == "all" ? nil : option.id
            dismiss()
        } label: {
            HStack {
                if let icon = option.icon {
                    Image(systemName: icon)
                        .foregroundStyle(option.color ?? .secondary)
                        .frame(width: 28)
                }
                Text(option.label)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedId == option.id || (option.id == "all" && selectedId == nil) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
