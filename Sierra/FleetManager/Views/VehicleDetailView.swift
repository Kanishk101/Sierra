import SwiftUI

// MARK: - VehicleDetailView
// Shows full vehicle info, assigned driver, documents, and trip history.

struct VehicleDetailView: View {

    @Environment(AppDataStore.self) private var store
    let vehicleId: UUID

    private var vehicle: Vehicle? { store.vehicle(for: vehicleId) }

    var body: some View {
        Group {
            if let vehicle {
                content(vehicle)
            } else {
                notFoundView
            }
        }
        .navigationTitle("Vehicle Detail")
        .navigationBarTitleDisplayMode(.inline)
        .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
        .onAppear {
            print("[VehicleDetailView] vehicleId=\(vehicleId) — found: \(vehicle != nil)")
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Not Found
    // ─────────────────────────────────────────────────────────────

    private var notFoundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
            Text("Vehicle Not Found")
                .font(SierraFont.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Main Content
    // ─────────────────────────────────────────────────────────────

    private func content(_ vehicle: Vehicle) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard(vehicle)
                specsCard(vehicle)
                metricsCard(vehicle)
                if let driver = assignedDriver(for: vehicle) {
                    driverCard(driver)
                }
                documentsSection(vehicle)
                tripsSection(vehicle)
            }
            .padding(16)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Header Card
    // ─────────────────────────────────────────────────────────────

    private func headerCard(_ v: Vehicle) -> some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: "car.fill")
                .font(.system(size: 28))
                .foregroundStyle(SierraTheme.Colors.sierraBlue)
                .frame(width: 60, height: 60)
                .background(SierraTheme.Colors.sierraBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(v.name)
                    .font(SierraFont.title3)
                    .foregroundStyle(SierraTheme.Colors.primaryText)

                Text("\(v.manufacturer) \(v.model) · \(v.year)")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.secondaryText)

                Text(v.licensePlate)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.1), in: Capsule())
            }

            Spacer()

            SierraBadge(v.status, size: .compact)
        }
        .padding(16)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Specs Card
    // ─────────────────────────────────────────────────────────────

    private func specsCard(_ v: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Specifications")

            detailRow(icon: "fuelpump.fill",      label: "Fuel Type",        value: v.fuelType.rawValue)
            detailRow(icon: "person.2.fill",      label: "Seating",          value: "\(v.seatingCapacity) seats")
            detailRow(icon: "paintbrush.fill",    label: "Color",            value: v.color)
            detailRow(icon: "barcode.viewfinder", label: "VIN",              value: v.vin)
        }
        .padding(16)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Metrics Card
    // ─────────────────────────────────────────────────────────────

    private func metricsCard(_ v: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Metrics")

            HStack(spacing: 0) {
                metricCell(label: "Odometer", value: String(format: "%.0f km", v.odometer))
                Divider().frame(height: 36)
                metricCell(label: "Total Trips", value: "\(v.totalTrips)")
                Divider().frame(height: 36)
                metricCell(label: "Total Dist.", value: String(format: "%.0f km", v.totalDistanceKm))
            }
        }
        .padding(16)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(SierraFont.body(17, weight: .bold))
                .foregroundStyle(SierraTheme.Colors.primaryText)
            Text(label)
                .font(SierraFont.caption2)
                .foregroundStyle(SierraTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Assigned Driver Card
    // ─────────────────────────────────────────────────────────────

    private func assignedDriver(for v: Vehicle) -> StaffMember? {
        guard let did = v.assignedDriverUUID else { return nil }
        return store.staffMember(for: did)
    }

    private func driverCard(_ driver: StaffMember) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Assigned Driver")

            HStack(spacing: 12) {
                SierraAvatarView(
                    initials: driver.initials,
                    size: 44,
                    gradient: SierraAvatarView.driver()
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(driver.displayName)
                        .font(SierraFont.body(15, weight: .semibold))
                        .foregroundStyle(SierraTheme.Colors.primaryText)
                    Text(driver.email)
                        .font(SierraFont.caption2)
                        .foregroundStyle(SierraTheme.Colors.secondaryText)
                }

                Spacer()

                Image(systemName: "person.fill.checkmark")
                    .font(.system(size: 18))
                    .foregroundStyle(SierraTheme.Colors.alpineMint)
            }
        }
        .padding(16)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Documents Section
    // ─────────────────────────────────────────────────────────────

    private func documentsSection(_ v: Vehicle) -> some View {
        let docs = store.vehicleDocuments(forVehicle: v.id)
        return VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Documents (\(docs.count))")

            if docs.isEmpty {
                Text("No documents on file.")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.secondaryText)
            } else {
                ForEach(docs) { doc in
                    docRow(doc)
                }
            }
        }
        .padding(16)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    private func docRow(_ doc: VehicleDocument) -> some View {
        HStack(spacing: 10) {
            Image(systemName: doc.isExpired ? "exclamationmark.triangle.fill" : "doc.fill")
                .font(SierraFont.caption1)
                .foregroundStyle(doc.isExpired ? SierraTheme.Colors.danger : doc.isExpiringSoon ? SierraTheme.Colors.warning : SierraTheme.Colors.sierraBlue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(doc.documentType.rawValue)
                    .font(SierraFont.body(13, weight: .semibold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                Text("Expires \(doc.expiryDate.formatted(.dateTime.day().month(.abbreviated).year()))")
                    .font(SierraFont.caption2)
                    .foregroundStyle(doc.isExpired ? SierraTheme.Colors.danger : SierraTheme.Colors.secondaryText)
            }

            Spacer()

            if doc.isExpired {
                Text("Expired")
                    .font(SierraFont.body(10, weight: .bold))
                    .foregroundStyle(SierraTheme.Colors.danger)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(SierraTheme.Colors.danger.opacity(0.1), in: Capsule())
            } else if doc.isExpiringSoon {
                Text("\(doc.daysUntilExpiry)d left")
                    .font(SierraFont.body(10, weight: .bold))
                    .foregroundStyle(SierraTheme.Colors.warning)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(SierraTheme.Colors.warning.opacity(0.1), in: Capsule())
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Trips Section
    // ─────────────────────────────────────────────────────────────

    private func tripsSection(_ v: Vehicle) -> some View {
        let vehicleTrips = store.trips.filter { $0.vehicleId == v.id.uuidString }
            .sorted { $0.scheduledDate > $1.scheduledDate }
            .prefix(5)

        return VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Recent Trips (\(store.trips.filter { $0.vehicleId == v.id.uuidString }.count))")

            if vehicleTrips.isEmpty {
                Text("No trips assigned to this vehicle.")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.secondaryText)
            } else {
                ForEach(vehicleTrips) { trip in
                    NavigationLink(value: trip.id) {
                        tripRow(trip)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tripStatusColor(trip.status))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(trip.origin) → \(trip.destination)")
                    .font(SierraFont.body(13, weight: .semibold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                    .lineLimit(1)
                Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(SierraFont.caption2)
                    .foregroundStyle(SierraTheme.Colors.secondaryText)
            }

            Spacer()

            Text(trip.status.rawValue)
                .font(SierraFont.body(10, weight: .bold))
                .foregroundStyle(tripStatusColor(trip.status))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(tripStatusColor(trip.status).opacity(0.1), in: Capsule())
        }
    }

    private func tripStatusColor(_ status: TripStatus) -> Color {
        switch status {
        case .active:    return .green
        case .scheduled: return SierraTheme.Colors.sierraBlue
        case .completed: return .gray
        case .cancelled: return .red
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────────

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(SierraFont.body(11, weight: .bold))
            .foregroundStyle(.secondary)
            .kerning(1.1)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(SierraFont.caption1)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(SierraFont.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(SierraFont.body(14, weight: .medium))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VehicleDetailView(vehicleId: Vehicle.mockData[0].id)
            .environment(AppDataStore.shared)
    }
}
