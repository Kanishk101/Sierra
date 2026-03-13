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
                SierraTheme.Colors.appBackground.ignoresSafeArea()

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
                                    .font(SierraFont.caption1)
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
                    .fill(step <= currentStep ? SierraTheme.Colors.ember : Color.gray.opacity(0.3))
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
                        .fill(step < currentStep ? SierraTheme.Colors.ember : Color.gray.opacity(0.2))
                        .frame(height: 2)
                        .frame(maxWidth: 60)
                }
            }
        }
        .padding(.horizontal, 60)
    }

    // ─────────────────────────────────
    // MARK: - Step 1: Trip Details
    // ─────────────────────────────────

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

            // Next button
            Button {
                withAnimation(.easeInOut) { currentStep = 2 }
            } label: {
                HStack {
                    Text("Next: Assign Driver")
                    Image(systemName: "arrow.right")
                }
                .font(SierraFont.body(16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(SierraTheme.Colors.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!step1Valid)
            .opacity(step1Valid ? 1 : 0.5)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    // ─────────────────────────────────
    // MARK: - Step 2: Assign Driver
    // ─────────────────────────────────

    private var step2View: some View {
        VStack(spacing: 0) {
            let drivers = store.availableDrivers()

            if drivers.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "person.slash.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray.opacity(0.4))
                    Text("No available drivers")
                        .font(SierraFont.body(16, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Ensure drivers are approved and set to Available.")
                        .font(SierraFont.caption1)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 30)
            } else {
                Text("Select Driver")
                    .font(SierraFont.body(18, weight: .bold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
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
                                            .font(SierraFont.body(14, weight: .bold))
                                            .foregroundStyle(.blue)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(driver.displayName)
                                        .font(SierraFont.subheadline)
                                        .foregroundStyle(SierraTheme.Colors.primaryText)
                                    Text(driver.phone ?? "No phone")
                                        .font(SierraFont.caption1)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedDriverId == driver.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(SierraTheme.Colors.ember)
                                }
                            }
                        }
                        .listRowBackground(
                            selectedDriverId == driver.id
                            ? SierraTheme.Colors.ember.opacity(0.06)
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
                .font(SierraFont.body(16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(SierraTheme.Colors.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!step2Valid)
            .opacity(step2Valid ? 1 : 0.5)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    // ─────────────────────────────────
    // MARK: - Step 3: Assign Vehicle
    // ─────────────────────────────────

    private var step3View: some View {
        VStack(spacing: 0) {
            let vehicles = store.availableVehicles()

            if vehicles.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "car.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray.opacity(0.4))
                    Text("No available vehicles")
                        .font(SierraFont.body(16, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Ensure vehicles are active and not assigned.")
                        .font(SierraFont.caption1)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 30)
            } else {
                Text("Select Vehicle")
                    .font(SierraFont.body(18, weight: .bold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)
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
                                        .font(SierraFont.subheadline)
                                        .foregroundStyle(SierraTheme.Colors.primaryText)

                                    HStack(spacing: 8) {
                                        Text(vehicle.licensePlate)
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.gray.opacity(0.1), in: Capsule())

                                        Text(vehicle.fuelType.description)
                                            .font(SierraFont.caption2)
                                            .foregroundStyle(.secondary)

                                        Text("· \(vehicle.seatingCapacity) seats")
                                            .font(SierraFont.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if selectedVehicleId == vehicle.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(SierraTheme.Colors.ember)
                                }
                            }
                        }
                        .listRowBackground(
                            selectedVehicleId == vehicle.id
                            ? SierraTheme.Colors.ember.opacity(0.06)
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
                .font(SierraFont.body(16, weight: .semibold))
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

        let adminId = AuthManager.shared.currentUser?.id ?? UUID()
        let now = Date()
        let trip = Trip(
            id: UUID(),
            taskId: Trip.generateTaskId(),
            driverId: driverId,
            vehicleId: vehicleId,
            createdByAdminId: adminId,
            origin: origin.trimmingCharacters(in: .whitespaces),
            destination: destination.trimmingCharacters(in: .whitespaces),
            deliveryInstructions: "",
            scheduledDate: scheduledDate,
            scheduledEndDate: nil,
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
            createdAt: now,
            updatedAt: now
        )

        isCreating = true
        do {
            try await store.addTrip(trip)

            // Update vehicle assignment
            if var v = store.vehicle(for: vehicleId) {
                v.assignedDriverId = driverId
                try await store.updateVehicle(v)
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
                .font(SierraFont.title2)
                .foregroundStyle(SierraTheme.Colors.primaryText)

            if let trip = createdTrip {
                VStack(spacing: 10) {
                    infoPill("Task ID", value: trip.taskId)
                    infoPill("Route", value: "\(trip.origin) → \(trip.destination)")

                    if let dId = trip.driverId,
                       let driver = store.staffMember(for: dId) {
                        infoPill("Driver", value: driver.displayName)
                    }
                    if let vId = trip.vehicleId,
                       let vehicle = store.vehicle(for: vId) {
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
                    .font(SierraFont.body(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(SierraTheme.Colors.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func infoPill(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(SierraFont.caption1)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(SierraFont.subheadline)
                .foregroundStyle(SierraTheme.Colors.primaryText)
            Spacer()
        }
    }
}

#Preview {
    CreateTripView()
        .environment(AppDataStore.shared)
}
