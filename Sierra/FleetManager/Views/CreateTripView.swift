import SwiftUI


/// 3-step trip creation wizard.
struct CreateTripView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppDataStore.self) private var store

    // MARK: - Step State

    @State private var currentStep = 1

    // Step 1 — Trip Details
    @State private var origin = ""
    @State private var destination = ""
    @State private var scheduledDate = Date()
    @State private var scheduledEndDate: Date = Date().addingTimeInterval(3600 * 8)
    @State private var priority: TripPriority = .normal
    @State private var notes = ""

    // Step 2 — Driver
    @State private var selectedDriverId: UUID?

    // Step 3 — Vehicle
    @State private var selectedVehicleId: UUID?

    // Success state
    @State private var createdTrip: Trip?
    @State private var showSuccess = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: - Validation

    private var step1Valid: Bool {
        !origin.trimmingCharacters(in: .whitespaces).isEmpty
        && !destination.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var step2Valid: Bool { selectedDriverId != nil }
    private var step3Valid: Bool { selectedVehicleId != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Step indicator
                    stepIndicator
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                    // Content
                    if showSuccess {
                        successCard
                    } else {
                        switch currentStep {
                        case 1:  step1View
                        case 2:  step2View
                        case 3:  step3View
                        default: EmptyView()
                        }
                    }
                }
            }
            .navigationTitle("Create Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if currentStep > 1 && !showSuccess {
                        Button {
                            withAnimation { currentStep -= 1 }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.caption)
                                Text("Back")
                            }
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(1...3, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .overlay {
                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                if step < 3 {
                    Rectangle()
                        .fill(step < currentStep ? Color.orange : Color.gray.opacity(0.2))
                        .frame(height: 2)
                        .frame(maxWidth: 60)
                }
            }
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Step 1: Trip Details

    private var step1View: some View {
        VStack(spacing: 0) {
            Form {
                Section("Route") {
                    TextField("Origin *", text: $origin)
                    TextField("Destination *", text: $destination)
                }
                Section("Schedule") {
                    DatePicker("Departure *",
                               selection: $scheduledDate,
                               in: Date()...,
                               displayedComponents: [.date, .hourAndMinute])
                    Picker("Priority", selection: $priority) {
                        ForEach(TripPriority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: scheduledDate) { _, newDate in
                scheduledEndDate = newDate.addingTimeInterval(3600 * 8)
            }

            // Next button
            Button {
                withAnimation(.easeInOut) { currentStep = 2 }
            } label: {
                HStack {
                    Text("Next: Assign Driver")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!step1Valid)
            .opacity(step1Valid ? 1 : 0.5)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Step 2: Assign Driver

    private var step2View: some View {
        VStack(spacing: 0) {
            let drivers = store.staff.filter {
                $0.role == .driver &&
                $0.status == .active &&
                $0.availability == .available
            }

            if drivers.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "person.slash.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray.opacity(0.4))
                    Text("No available drivers")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Ensure drivers are approved and set to Available.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 30)
            } else {
                Text("Select Driver")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)

                List {
                    ForEach(drivers) { driver in
                        Button {
                            selectedDriverId = driver.id
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(driver.initials)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.blue)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(driver.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(driver.phone ?? "No phone")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedDriverId == driver.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .listRowBackground(
                            selectedDriverId == driver.id
                            ? Color.orange.opacity(0.06)
                            : Color.clear
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // Next button
            Button {
                withAnimation(.easeInOut) { currentStep = 3 }
            } label: {
                HStack {
                    Text("Next: Assign Vehicle")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!step2Valid)
            .opacity(step2Valid ? 1 : 0.5)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Step 3: Assign Vehicle

    private var step3View: some View {
        VStack(spacing: 0) {
            let vehicles = store.vehicles.filter {
                $0.status == .idle || $0.status == .active
            }

            if vehicles.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "car.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray.opacity(0.4))
                    Text("No available vehicles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Ensure vehicles are active and not assigned.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 30)
            } else {
                Text("Select Vehicle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)

                List {
                    ForEach(vehicles) { vehicle in
                        Button {
                            selectedVehicleId = vehicle.id
                        } label: {
                            HStack(spacing: 12) {
                                // Color dot
                                Circle()
                                    .fill(colorDot(vehicle.color))
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(vehicle.name) \(vehicle.model)")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)

                                    HStack(spacing: 8) {
                                        Text(vehicle.licensePlate)
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.gray.opacity(0.1), in: Capsule())

                                        Text(vehicle.fuelType.description)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        Text("· \(vehicle.seatingCapacity) seats")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if selectedVehicleId == vehicle.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .listRowBackground(
                            selectedVehicleId == vehicle.id
                            ? Color.orange.opacity(0.06)
                            : Color.clear
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // Create button
            Button {
                Task { await createTrip() }
            } label: {
                HStack {
                    if isCreating {
                        ProgressView().scaleEffect(0.9).tint(.white)
                    } else {
                        Text("Create Trip")
                        Image(systemName: "checkmark")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!step3Valid || isCreating)
            .opacity(step3Valid && !isCreating ? 1 : 0.5)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Color Dot Helper

    private func colorDot(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "white":  .gray.opacity(0.3)
        case "black":  .black
        case "red":    .red
        case "blue":   .blue
        case "silver": .gray
        case "gray", "grey": .gray
        case "green":  .green
        case "yellow": .yellow
        default:       .purple
        }
    }

    // MARK: - Create Trip

    @MainActor
    private func createTrip() async {
        guard let driverId = selectedDriverId,
              let vehicleId = selectedVehicleId else { return }

        isCreating = true
        // Geocode both addresses concurrently before creating the trip
        async let originResult = geocodeAddress(origin.trimmingCharacters(in: .whitespaces))
        async let destResult = geocodeAddress(destination.trimmingCharacters(in: .whitespaces))
        let (originCoords, destCoords) = await (originResult, destResult)
        do {
            let conflict = try await TripService.checkOverlap(
                driverId: driverId,
                vehicleId: vehicleId,
                start: scheduledDate,
                end: scheduledEndDate
            )
            if conflict.driverConflict {
                errorMessage = "This driver already has a trip assigned in that time slot."
                showError = true
                isCreating = false
                return
            }
            if conflict.vehicleConflict {
                errorMessage = "This vehicle is already assigned to another trip in that time slot."
                showError = true
                isCreating = false
                return
            }

            let adminId = AuthManager.shared.currentUser?.id ?? UUID()
            let now = Date()
            let trip = Trip(
                id: UUID(),
                taskId: TripService.newTaskId(),
                driverId: driverId.uuidString,
                vehicleId: vehicleId.uuidString,
                createdByAdminId: adminId.uuidString,
                origin: origin.trimmingCharacters(in: .whitespaces),
                destination: destination.trimmingCharacters(in: .whitespaces),
                originLatitude: originCoords?.0,
                originLongitude: originCoords?.1,
                destinationLatitude: destCoords?.0,
                destinationLongitude: destCoords?.1,
                routePolyline: nil,
                deliveryInstructions: "",
                scheduledDate: scheduledDate,
                scheduledEndDate: scheduledEndDate,
                actualStartDate: nil,
                actualEndDate: nil,
                startMileage: nil,
                endMileage: nil,
                notes: notes,
                status: .scheduled,
                priority: priority,
                proofOfDeliveryId: nil,
                preInspectionId: nil,
                postInspectionId: nil,
                driverRating: nil,
                driverRatingNote: nil,
                ratedById: nil,
                ratedAt: nil,
                createdAt: now,
                updatedAt: now
            )

            try await store.addTrip(trip)
            try await TripService.markResourcesBusy(driverId: driverId, vehicleId: vehicleId)

            if var v = store.vehicle(for: vehicleId) {
                v.status = .busy
                v.assignedDriverId = driverId.uuidString
                try? await store.updateVehicle(v)
            }
            if var driver = store.staffMember(for: driverId) {
                driver.availability = .busy
                try? await store.updateStaffMember(driver)
            }

            createdTrip = trip
            withAnimation(.spring(duration: 0.4)) { showSuccess = true }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isCreating = false
    }

    // MARK: - Success Card

    private var successCard: some View {
        VStack(spacing: 24) {
            Spacer()

            AnimatedCheckmarkView(size: 80)
                .padding(.bottom, 8)

            Text("Trip Created!")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            if let trip = createdTrip {
                VStack(spacing: 10) {
                    infoPill("Task ID", value: trip.taskId)
                    infoPill("Route", value: "\(trip.origin) \u{2192} \(trip.destination)")

                    if let dId = trip.driverId,
                       let dUUID = UUID(uuidString: dId),
                       let driver = store.staffMember(for: dUUID) {
                        infoPill("Driver", value: driver.displayName)
                    }
                    if let vId = trip.vehicleId,
                       let vUUID = UUID(uuidString: vId),
                       let vehicle = store.vehicle(for: vUUID) {
                        infoPill("Vehicle", value: "\(vehicle.name) \(vehicle.model)")
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func infoPill(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    // MARK: - Geocoding (Mapbox v5, token from Info.plist — never hardcoded)

    private func geocodeAddress(_ address: String) async -> (Double, Double)? {
        guard !address.isEmpty,
              let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String,
              !token.isEmpty else { return nil }
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let urlString = "https://api.mapbox.com/geocoding/v5/mapbox.places/\(encoded).json?access_token=\(token)&limit=1&country=IN"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let features = json?["features"] as? [[String: Any]]
            let geometry = features?.first?["geometry"] as? [String: Any]
            let coords = geometry?["coordinates"] as? [Double]  // [lng, lat]
            if let lng = coords?[0], let lat = coords?[1] {
                return (lat, lng)
            }
        } catch {
            print("[CreateTrip] Geocoding failed for '\(address)': \(error)")
        }
        return nil
    }
}

#Preview {
    CreateTripView()
        .environment(AppDataStore.shared)
}
