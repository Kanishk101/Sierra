import SwiftUI
import Supabase

/// FM view of a specific driver's profile, stats, and trip history.
/// Safeguard 4: driver trip query scoped to one driver with .limit(50).
/// Safeguard 6: deactivation shows confirmation alert.
/// Safeguard 7: average rating computed from non-nil ratings only.
struct DriverHistoryView: View {

    let driverId: UUID
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var driverTrips: [Trip] = []
    @State private var isLoading = true
    @State private var showDeactivateAlert = false
    @State private var isDeactivating = false
    @State private var showRateSheet = false
    @State private var tripToRate: Trip?
    @State private var ratingValue = 3
    @State private var ratingNote = ""
    @State private var isRating = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var driver: StaffMember? {
        store.staff.first(where: { $0.id == driverId })
    }

    // Safeguard 7: average from non-nil ratings
    private var averageRating: Double? {
        let rated = driverTrips.compactMap(\.driverRating)
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0, +)) / Double(rated.count)
    }

    private var totalDistance: Double {
        driverTrips.compactMap { trip -> Double? in
            guard let s = trip.startMileage, let e = trip.endMileage else { return nil }
            return e - s
        }.reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileCard
                statsRow
                Divider()
                tripHistorySection
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Driver History")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadDriverTrips()
        }
        .alert("Deactivate Driver?", isPresented: $showDeactivateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                Task { await deactivateDriver() }
            }
        } message: {
            Text("This driver will lose access to the app immediately. You can reactivate them from Staff Management.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .sheet(isPresented: $showRateSheet) {
            rateDriverSheet
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 72, height: 72)
                .overlay(
                    Text(String((driver?.name ?? "D").prefix(2)).uppercased())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                )
            Text(driver?.name ?? "Unknown").font(.title3.weight(.bold))
            HStack(spacing: 16) {
                if let phone = driver?.phone {
                    Label(phone, systemImage: "phone").font(.caption).foregroundStyle(.secondary)
                }
                if let joined = driver?.joinedDate {
                    Label("Joined \(joined.formatted(.dateTime.month(.abbreviated).year()))", systemImage: "calendar")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            // Deactivate (Safeguard 6)
            if driver?.status == .active {
                Button {
                    showDeactivateAlert = true
                } label: {
                    Text("Deactivate Driver")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(.red.opacity(0.08), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(label: "Trips", value: "\(driverTrips.count)")
            Divider().frame(height: 32)
            statCell(label: "Distance", value: "\(Int(totalDistance)) km")
            Divider().frame(height: 32)
            statCell(label: "Avg Rating", value: averageRating != nil ? String(format: "%.1f ★", averageRating!) : "N/A")
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.subheadline.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trip History

    private var tripHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPLETED TRIPS").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(40)
            } else if driverTrips.isEmpty {
                Text("No completed trips yet").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(40)
            } else {
                ForEach(driverTrips) { trip in
                    tripRow(trip)
                }
            }
        }
    }

    private func tripRow(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(trip.origin) \u{2192} \(trip.destination)")
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer()
                if let rating = trip.driverRating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundStyle(i <= rating ? .orange : .gray.opacity(0.3))
                        }
                    }
                } else {
                    Button("Rate") {
                        tripToRate = trip
                        ratingValue = 3
                        ratingNote = ""
                        showRateSheet = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SierraTheme.Colors.info)
                }
            }

            HStack(spacing: 12) {
                if let start = trip.actualStartDate {
                    Text(start.formatted(.dateTime.month(.abbreviated).day())).font(.caption).foregroundStyle(.secondary)
                }
                if let s = trip.startMileage, let e = trip.endMileage {
                    Text("\(Int(e - s)) km").font(.caption).foregroundStyle(.secondary)
                }
                if let start = trip.actualStartDate, let end = trip.actualEndDate {
                    let hrs = end.timeIntervalSince(start) / 3600
                    Text(String(format: "%.1fh", hrs)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Rate Driver Sheet

    private var rateDriverSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Rate Driver Performance").font(.headline)

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= ratingValue ? "star.fill" : "star")
                            .font(.title)
                            .foregroundStyle(i <= ratingValue ? .orange : .gray.opacity(0.3))
                            .onTapGesture { ratingValue = i }
                    }
                }

                TextField("Optional note...", text: $ratingNote)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 16)

                Button {
                    Task { await submitRating() }
                } label: {
                    HStack {
                        if isRating { ProgressView().tint(.white) }
                        Text("Submit Rating").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(SierraTheme.Colors.ember, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isRating)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Rate Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRateSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submitRating() async {
        guard let trip = tripToRate else { return }
        isRating = true
        do {
            try await TripService.rateDriver(
                tripId: trip.id,
                rating: ratingValue,
                note: ratingNote.isEmpty ? nil : ratingNote,
                ratedById: currentUserId
            )
            showRateSheet = false
            await loadDriverTrips()
        } catch {
            errorMessage = "Rating failed: \(error.localizedDescription)"
            showError = true
        }
        isRating = false
    }

    // MARK: - Load (Safeguard 4: scoped + limited)

    private func loadDriverTrips() async {
        isLoading = true
        do {
            let trips: [Trip] = try await supabase
                .from("trips")
                .select()
                .eq("driver_id", value: driverId.uuidString)
                .eq("status", value: TripStatus.completed.rawValue)
                .order("actual_end_date", ascending: false)
                .limit(50)
                .execute()
                .value
            driverTrips = trips
        } catch {
            print("[DriverHistory] Load error: \(error)")
        }
        isLoading = false
    }

    // MARK: - Deactivate (Safeguard 6: confirmation already shown)

    private func deactivateDriver() async {
        guard var d = driver else { return }
        isDeactivating = true
        d.status = .suspended
        do {
            try await StaffMemberService.updateStaffMember(d)
            // Notify driver
            try? await NotificationService.insertNotification(
                recipientId: driverId,
                type: .general,
                title: "Account Suspended",
                body: "Your account has been suspended by fleet management.",
                entityType: "staff_member",
                entityId: driverId
            )
            dismiss()
        } catch {
            errorMessage = "Deactivation failed: \(error.localizedDescription)"
            showError = true
        }
        isDeactivating = false
    }
}
