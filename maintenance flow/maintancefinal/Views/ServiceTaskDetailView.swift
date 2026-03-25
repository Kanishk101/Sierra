import SwiftUI

struct ServiceTaskDetailView: View {
    @State private var task: ServiceTask
    var onUpdate: (ServiceTask) -> Void

    init(task: ServiceTask, onUpdate: @escaping (ServiceTask) -> Void) {
        _task = State(initialValue: task)
        self.onUpdate = onUpdate
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                taskHeaderCard
                checklistCard
                inventoryCard
                statusBanner
                actionButtons
            }
            .padding(.bottom, 32)
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Service Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var taskHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(task.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.appTextPrimary)
            
            Text(task.description)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Label(task.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                Text(task.serviceType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appOrange.opacity(0.1))
                    .foregroundStyle(Color.appOrange)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var statusBanner: some View {
        let status = task.status
        return HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(status.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(status.color)
            }
            Spacer()
        }
        .padding(14)
        .background(status.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(status.color.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("CHECKLIST", systemImage: "checklist")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)
                .kerning(1)

            ForEach($task.checklistItems) { $item in
                Toggle(isOn: $item.isChecked) {
                    Text(item.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextPrimary)
                }
                .onChange(of: item.isChecked) { _, _ in
                    onUpdate(task)
                }
                .tint(Color.appOrange)
                Divider()
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private var inventoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("REQUIRED PARTS", systemImage: "shippingbox.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .kerning(1)
                Spacer()
            }

            if task.requiredParts.isEmpty {
                Text("No required parts")
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
            } else {
                ForEach(task.requiredParts) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(item.isAvailable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(item.name).font(.subheadline).foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Text("x\(item.quantity)").font(.caption.weight(.medium)).foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if task.status != .completed {
            Button {
                task.status = .completed
                onUpdate(task)
            } label: {
                Label("Mark as Completed", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 16)
        }
    }
}
