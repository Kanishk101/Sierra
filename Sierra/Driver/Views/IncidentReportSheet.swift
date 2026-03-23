import SwiftUI
import Supabase

/// Lightweight incident report — not an emergency, just a note for the log.
struct IncidentReportSheet: View {

    @Environment(\.dismiss) private var dismiss

    enum IncidentType: String, CaseIterable {
        case roadClosure   = "Road Closure"
        case construction  = "Construction"
        case accidentAhead = "Accident Ahead"
        case hazard        = "Hazard"
        case other         = "Other"
    }

    @State private var incidentType: IncidentType = .hazard
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("INCIDENT TYPE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary).kerning(1)

                    Picker("Type", selection: $incidentType) {
                        ForEach(IncidentType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("NOTES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary).kerning(1)

                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 16)

                if submitted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Report submitted").font(.subheadline.weight(.medium))
                    }
                }

                Button {
                    Task { await submitReport() }
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text("Submit Report")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(SierraTheme.Colors.ember, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSubmitting || submitted)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("Report Incident")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submitReport() async {
        isSubmitting = true
        // Insert as a simple activity log via direct Supabase call
        do {
            struct LogPayload: Encodable {
                let staff_id: String
                let activity_type: String
                let severity: String
                let message: String
                let performed_at: String
            }
            // C-04 FIX: Guard against nil auth
            guard let userId = AuthManager.shared.currentUser?.id else {
                isSubmitting = false
                return
            }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            try await supabase
                .from("activity_logs")
                .insert(LogPayload(
                    staff_id: userId.uuidString,
                    activity_type: incidentType.rawValue,  // H-03 FIX: use selected type
                    severity: "Medium",
                    message: "[\(incidentType.rawValue)] \(notes)",
                    performed_at: iso.string(from: Date())
                ))
                .execute()
            submitted = true
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            print("[IncidentReport] Submit error: \(error)")
        }
        isSubmitting = false
    }
}
