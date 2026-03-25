import SwiftUI

/// Inventory tab — shows spare parts requests across all tasks.
/// VIN scanner available via toolbar button.
struct InventoryView: View {
    @Environment(AppDataStore.self) private var store
    @State private var showVINScanner = false
    @State private var scannedVIN = ""

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    /// All spare parts requests for tasks assigned to this technician
    private var allParts: [SparePartsRequest] {
        let myTaskIds = Set(store.maintenanceTasks.filter { $0.assignedToId == currentUserId }.map(\.id))
        return store.sparePartsRequests.filter { myTaskIds.contains($0.maintenanceTaskId) }
    }

    private var pendingParts: [SparePartsRequest] { allParts.filter { $0.status == .pending } }
    private var approvedParts: [SparePartsRequest] { allParts.filter { $0.status == .approved } }
    private var fulfilledParts: [SparePartsRequest] { allParts.filter { $0.status == .fulfilled } }
    private var rejectedParts: [SparePartsRequest] { allParts.filter { $0.status == .rejected } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Summary stats
                statsRow

                // Pending
                if !pendingParts.isEmpty {
                    partsSection(title: "Pending Approval", parts: pendingParts, accent: .orange)
                }

                // Approved
                if !approvedParts.isEmpty {
                    partsSection(title: "Approved", parts: approvedParts, accent: .blue)
                }

                // Fulfilled
                if !fulfilledParts.isEmpty {
                    partsSection(title: "Fulfilled", parts: fulfilledParts, accent: .green)
                }

                // Rejected
                if !rejectedParts.isEmpty {
                    partsSection(title: "Rejected", parts: rejectedParts, accent: .red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .overlay {
            if allParts.isEmpty { emptyState }
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showVINScanner = true } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.appOrange)
                }
            }
        }
        .sheet(isPresented: $showVINScanner) {
            NavigationStack {
                VINScannerView(scannedVIN: $scannedVIN)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statPill(count: pendingParts.count, label: "Pending", color: .orange)
            statPill(count: approvedParts.count, label: "Approved", color: .blue)
            statPill(count: fulfilledParts.count, label: "Ready", color: .green)
        }
    }

    private func statPill(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Parts Section

    private func partsSection(title: String, parts: [SparePartsRequest], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text("\(parts.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(accent.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ForEach(Array(parts.enumerated()), id: \.element.id) { idx, part in
                partRow(part, accent: accent)
                if idx < parts.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }

            Spacer(minLength: 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.appDivider, lineWidth: 1)
        )
    }

    private func partRow(_ part: SparePartsRequest, accent: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 14))
                .foregroundStyle(accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(part.partName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)

                // Associated task
                if let task = store.maintenanceTasks.first(where: { $0.id == part.maintenanceTaskId }) {
                    Text(task.title)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("×\(part.quantity)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.3))
            Text("No Parts")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            Text("Parts requests for your tasks\nwill appear here.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
