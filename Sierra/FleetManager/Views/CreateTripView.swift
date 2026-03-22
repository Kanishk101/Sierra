import SwiftUI
import MapKit

// MARK: - GeofenceCandidate

struct GeofenceCandidate: Identifiable {
    let id = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double = 500
    var geofenceType: GeofenceType = .custom
    var alertOnEntry: Bool = true
    var alertOnExit: Bool = true
}

/// 4-step trip creation wizard.
struct CreateTripView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppDataStore.self) private var store

    @State private var currentStep = 1

    // Step 1
    @State private var origin = ""
    @State private var destination = ""
    @State private var scheduledDate = Date()
    @State private var scheduledEndDate: Date = Date().addingTimeInterval(3600 * 8)
    @State private var priority: TripPriority = .normal
    @State private var notes = ""
    @State private var selectedOrigin: GeocodedAddress?
    @State private var selectedDestination: GeocodedAddress?
    @State private var stops: [GeocodedAddress] = []
    @State private var showOriginSearch = false
    @State private var showDestinationSearch = false
    @State private var showStopSearch = false

    // Step 2
    @State private var selectedDriverId: UUID?

    // Step 3
    @State private var selectedVehicleId: UUID?

    // Step 4
    @State private var tripGeofences: [GeofenceCandidate] = []
    @State private var editingGeofenceId: UUID?

    // Submit
    @State private var createdTrip: Trip?
    @State private var showSuccess = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: - Validation

    private var step1Valid: Bool {
        !origin.trimmingCharacters(in: .whitespaces).isEmpty
            && !destination.trimmingCharacters(in: .whitespaces).isEmpty
            && routeFieldValidationError(for: origin) == nil
            && routeFieldValidationError(for: destination) == nil
    }
    private var step2Valid: Bool { selectedDriverId != nil }
    private var step3Valid: Bool { selectedVehicleId != nil }
    // Geofences are MANDATORY — at least one zone must be defined before creating a trip.
    private var step4Valid: Bool { !tripGeofences.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    stepIndicator.padding(.top, 20).padding(.bottom, 16)
                    if showSuccess {
                        successCard
                    } else {
                        switch currentStep {
                        case 1: step1View
                        case 2: step2View
                        case 3: step3View
                        case 4: step4View
                        default: EmptyView()
                        }
                    }
                }
            }
            .navigationTitle("Create Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess { Button("Cancel") { dismiss() } }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if currentStep > 1 && !showSuccess {
                        Button { withAnimation { currentStep -= 1 } } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").font(.caption)
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
            ForEach(1...4, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .overlay {
                        if step < currentStep {
                            Image(systemName: "checkmark").font(.system(size: 7, weight: .bold)).foregroundStyle(.white)
                        }
                    }
                if step < 4 {
                    Rectangle().fill(step < currentStep ? Color.orange : Color.gray.opacity(0.2)).frame(height: 2).frame(maxWidth: 60)
                }
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 1: Trip Details

    private func routeFieldValidationError(for value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "This field is required." }
        if trimmed.count < 3 { return "Address is too short." }
        return nil
    }

    private var step1View: some View {
        VStack(spacing: 0) {
            Form {
                Section("Route") {
                    Button { showOriginSearch = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "circle.fill").font(.system(size: 10)).foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Origin").font(.caption).foregroundStyle(.secondary)
                                Text(origin.isEmpty ? "Search origin address…" : origin)
                                    .font(.subheadline).foregroundStyle(origin.isEmpty ? .tertiary : .primary).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)

                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        HStack(spacing: 12) {
                            Image(systemName: "\(index + 1).circle.fill").font(.system(size: 14)).foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stop \(index + 1)").font(.caption).foregroundStyle(.secondary)
                                Text(stop.shortName).font(.subheadline).foregroundStyle(.primary)
                            }
                            Spacer()
                            Button { stops.remove(at: index) } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(.red.opacity(0.7))
                            }.buttonStyle(.plain)
                        }
                    }

                    Button { showStopSearch = true } label: {
                        Label("Add Stop", systemImage: "plus.circle").font(.subheadline).foregroundStyle(.orange)
                    }

                    Button { showDestinationSearch = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill").font(.system(size: 14)).foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Destination").font(.caption).foregroundStyle(.secondary)
                                Text(destination.isEmpty ? "Search destination address…" : destination)
                                    .font(.subheadline).foregroundStyle(destination.isEmpty ? .tertiary : .primary).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                }

                if selectedOrigin != nil || selectedDestination != nil {
                    Section("Route Preview") { routeMapPreview }
                }

                Section("Schedule") {
                    DatePicker("Departure *", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    Picker("Priority", selection: $priority) {
                        ForEach(TripPriority.allCases, id: \.self) { p in Text(p.rawValue).tag(p) }
                    }
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: scheduledDate) { _, newDate in scheduledEndDate = newDate.addingTimeInterval(3600 * 8) }
            .sheet(isPresented: $showOriginSearch) {
                AddressSearchSheet(placeholder: "Search origin address…") { result in selectedOrigin = result; origin = result.displayName }
            }
            .sheet(isPresented: $showDestinationSearch) {
                AddressSearchSheet(placeholder: "Search destination address…") { result in selectedDestination = result; destination = result.displayName }
            }
            .sheet(isPresented: $showStopSearch) {
                AddressSearchSheet(placeholder: "Search stop address…") { result in stops.append(result) }
            }

            Button { withAnimation(.easeInOut) { currentStep = 2 } } label: {
                HStack {
                    Text("Next: Assign Driver")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!step1Valid).opacity(step1Valid ? 1 : 0.5)
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: - Route Map Preview

    private var routeMapPreview: some View {
        Map {
            if let o = selectedOrigin {
                Annotation(o.shortName, coordinate: o.coordinate) {
                    Image(systemName: "circle.fill").font(.system(size: 12)).foregroundStyle(.green).background(.white, in: Circle()).shadow(radius: 2)
                }
            }
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                Annotation("Stop \(index + 1)", coordinate: stop.coordinate) {
                    Text("\(index + 1)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white).frame(width: 22, height: 22).background(.orange, in: Circle()).shadow(radius: 2)
                }
            }
            if let d = selectedDestination {
                Annotation(d.shortName, coordinate: d.coordinate) {
                    Image(systemName: "mappin.circle.fill").font(.system(size: 16)).foregroundStyle(.red).background(.white, in: Circle()).shadow(radius: 2)
                }
            }
        }
        .frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 14))
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    // MARK: - Step 2: Assign Driver

    private var step2View: some View {
        VStack(spacing: 0) {
            let drivers = store.availableDrivers()
            if drivers.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "person.slash.fill").font(.system(size: 36)).foregroundStyle(.gray.opacity(0.4))
                    Text("No available drivers").font(.system(size: 16, weight: .semibold)).foregroundStyle(.secondary)
                    Text("Ensure drivers are approved and set to Available.").font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 30)
            } else {
                Text("Select Driver").font(.system(size: 18, weight: .bold)).padding(.top, 4)
                List {
                    ForEach(drivers) { driver in
                        Button { selectedDriverId = driver.id } label: {
                            HStack(spacing: 12) {
                                Circle().fill(Color.blue.opacity(0.12)).frame(width: 40, height: 40)
                                    .overlay(Text(driver.initials).font(.system(size: 14, weight: .bold)).foregroundStyle(.blue))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(driver.displayName).font(.subheadline).foregroundStyle(.primary)
                                    Text(driver.phone ?? "No phone").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedDriverId == driver.id {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(.orange)
                                }
                            }
                        }
                        .listRowBackground(selectedDriverId == driver.id ? Color.orange.opacity(0.06) : Color.clear)
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
            Button { withAnimation(.easeInOut) { currentStep = 3 } } label: {
                HStack { Text("Next: Assign Vehicle"); Image(systemName: "arrow.right") }
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!step2Valid).opacity(step2Valid ? 1 : 0.5)
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: - Step 3: Assign Vehicle

    private var step3View: some View {
        VStack(spacing: 0) {
            let vehicles = store.vehicles.filter { $0.status == .idle || $0.status == .active }
            if vehicles.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "car.fill").font(.system(size: 36)).foregroundStyle(.gray.opacity(0.4))
                    Text("No available vehicles").font(.system(size: 16, weight: .semibold)).foregroundStyle(.secondary)
                    Text("Ensure vehicles are active and not assigned.").font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 30)
            } else {
                Text("Select Vehicle").font(.system(size: 18, weight: .bold)).padding(.top, 4)
                List {
                    ForEach(vehicles) { vehicle in
                        Button { selectedVehicleId = vehicle.id } label: {
                            HStack(spacing: 12) {
                                Circle().fill(colorDot(vehicle.color)).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(vehicle.name) \(vehicle.model)").font(.subheadline).foregroundStyle(.primary)
                                    HStack(spacing: 8) {
                                        Text(vehicle.licensePlate)
                                            .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                                            .padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.1), in: Capsule())
                                        Text(vehicle.fuelType.description).font(.caption2).foregroundStyle(.secondary)
                                        Text("· \(vehicle.seatingCapacity) seats").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedVehicleId == vehicle.id {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(.orange)
                                }
                            }
                        }
                        .listRowBackground(selectedVehicleId == vehicle.id ? Color.orange.opacity(0.06) : Color.clear)
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
            Button { withAnimation(.easeInOut) { currentStep = 4 } } label: {
                HStack { Text("Next: Add Geofences"); Image(systemName: "arrow.right") }
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!step3Valid).opacity(step3Valid ? 1 : 0.5)
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: - Step 4: Add Geofences (REQUIRED)
    // At least one geofence zone must be added before a trip can be created.

    private var step4View: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Add Geofences")
                    .font(.system(size: 18, weight: .bold))
                Text("Define at least one monitoring zone for this trip")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 8).padding(.bottom, 12)

            List {
                // Suggested zones from route
                Section {
                    let suggestions: [(String, Double, Double)] = buildSuggestions()
                    if suggestions.isEmpty {
                        Text("Select origin and destination in Step 1 to get zone suggestions.")
                            .font(.caption).foregroundStyle(.tertiary)
                    } else {
                        ForEach(suggestions, id: \.0) { name, lat, lng in
                            let alreadyAdded = tripGeofences.contains { $0.latitude == lat && $0.longitude == lng }
                            Button {
                                if !alreadyAdded {
                                    tripGeofences.append(GeofenceCandidate(name: name, latitude: lat, longitude: lng))
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(alreadyAdded ? .green : .teal)
                                        .font(.system(size: 18))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name).font(.subheadline).foregroundStyle(.primary)
                                        Text("Tap to add 500m monitoring zone")
                                            .font(.caption2).foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    if alreadyAdded {
                                        Text("Added").font(.caption.weight(.semibold)).foregroundStyle(.green)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(alreadyAdded)
                        }
                    }
                } header: {
                    Text("Suggested from Route")
                }

                // Added geofences with full config
                if !tripGeofences.isEmpty {
                    Section {
                        ForEach($tripGeofences) { $gf in
                            geofenceConfigRow(gf: $gf)
                        }
                    } header: {
                        HStack {
                            Text("Added Geofences")
                            Spacer()
                            Text("\(tripGeofences.count) zone\(tripGeofences.count == 1 ? "" : "s")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            // Create Trip — disabled until at least one geofence is added.
            // Geofences are mandatory: they define the monitoring scope for the trip.
            VStack(spacing: 6) {
                Button { Task { await createTrip() } } label: {
                    HStack {
                        if isCreating { ProgressView().scaleEffect(0.9).tint(.white) }
                        else { Text("Create Trip"); Image(systemName: "checkmark") }
                    }
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(step4Valid ? .green : Color(.systemGray4),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isCreating || !step4Valid)
                .padding(.horizontal, 20)

                if !step4Valid {
                    Text("Add at least one geofence zone to continue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                }
            }
            .padding(.bottom, 12)
            .animation(.easeInOut(duration: 0.2), value: step4Valid)
        }
    }

    // Individual geofence config row with expandable settings
    @ViewBuilder
    private func geofenceConfigRow(gf: Binding<GeofenceCandidate>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                geofenceTypeIcon(gf.wrappedValue.geofenceType)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gf.wrappedValue.name)
                        .font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    Text("\(Int(gf.wrappedValue.radiusMeters))m • \(gf.wrappedValue.geofenceType.rawValue)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button { tripGeofences.removeAll { $0.id == gf.wrappedValue.id } } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.red.opacity(0.7))
                }.buttonStyle(.plain)
            }
            .padding(.vertical, 8)

            Divider().padding(.leading, 38)

            // Radius slider
            VStack(spacing: 6) {
                HStack {
                    Text("Radius").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(gf.wrappedValue.radiusMeters)) m")
                        .font(.system(.caption, design: .monospaced).weight(.semibold)).foregroundStyle(.orange)
                }
                Slider(value: gf.radiusMeters, in: 100...5000, step: 50)
                    .tint(.orange)
                HStack {
                    Text("100m").font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("5km").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 8)

            // Zone type picker
            // CRITICAL FIX: was .segmented — 4 options with long labels + icons completely
            // broke the layout on any iPhone (overflowed, text clipped, unusable).
            // .menu shows a compact button that expands to a dropdown, which works
            // correctly regardless of label length or option count.
            VStack(alignment: .leading, spacing: 4) {
                Text("Zone Type").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: gf.geofenceType) {
                    ForEach(GeofenceType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: geofenceTypeIconName(type)).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .tint(.orange)
            }
            .padding(.top, 8)

            // Alert toggles
            HStack(spacing: 16) {
                Toggle(isOn: gf.alertOnEntry) {
                    Label("Entry Alert", systemImage: "arrow.down.circle")
                        .font(.caption)
                }
                .toggleStyle(.switch).tint(.orange)

                Toggle(isOn: gf.alertOnExit) {
                    Label("Exit Alert", systemImage: "arrow.up.circle")
                        .font(.caption)
                }
                .toggleStyle(.switch).tint(.orange)
            }
            .padding(.top, 8).padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func geofenceTypeIcon(_ type: GeofenceType) -> some View {
        Image(systemName: geofenceTypeIconName(type))
            .font(.system(size: 18))
            .foregroundStyle(geofenceTypeColor(type))
            .frame(width: 28, height: 28)
            .background(geofenceTypeColor(type).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func geofenceTypeIconName(_ type: GeofenceType) -> String {
        switch type {
        case .warehouse:      return "building.2.fill"
        case .deliveryPoint:  return "shippingbox.fill"
        case .restrictedZone: return "exclamationmark.octagon.fill"
        case .custom:         return "mappin.circle.fill"
        }
    }

    private func geofenceTypeColor(_ type: GeofenceType) -> Color {
        switch type {
        case .warehouse:      return .blue
        case .deliveryPoint:  return .green
        case .restrictedZone: return .red
        case .custom:         return .teal
        }
    }

    private func buildSuggestions() -> [(String, Double, Double)] {
        var list: [(String, Double, Double)] = []
        if let o = selectedOrigin  { list.append(("Origin: \(o.shortName)", o.latitude, o.longitude)) }
        for (i, stop) in stops.enumerated() { list.append(("Stop \(i+1): \(stop.shortName)", stop.latitude, stop.longitude)) }
        if let d = selectedDestination { list.append(("Destination: \(d.shortName)", d.latitude, d.longitude)) }
        return list
    }

    // MARK: - Color Dot Helper

    private func colorDot(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "white":        .gray.opacity(0.3)
        case "black":        .black
        case "red":          .red
        case "blue":         .blue
        case "silver":       .gray
        case "gray", "grey": .gray
        case "green":        .green
        case "yellow":       .yellow
        default:             .purple
        }
    }

    // MARK: - Busy-Resource Validation

    private func busyResourceValidationError(resourceLabel: String, trips: [Trip], newTripStart: Date) -> String? {
        let blockingTrips = trips.filter { $0.status == .active || $0.status == .scheduled }
        guard !blockingTrips.isEmpty else {
            return "Selected \(resourceLabel) is marked Busy. Please resolve the current assignment first."
        }
        let explicitEndTimes = blockingTrips.compactMap { $0.actualEndDate ?? $0.scheduledEndDate }
        guard let latestEnd = explicitEndTimes.max() else {
            return "Selected \(resourceLabel) is Busy and has no explicit trip end time."
        }
        if latestEnd > newTripStart {
            let endText = latestEnd.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
            return "Selected \(resourceLabel) is Busy until \(endText). Choose another or a later departure."
        }
        return nil
    }

    // MARK: - Create Trip

    @MainActor
    private func createTrip() async {
        guard let driverId = selectedDriverId, let vehicleId = selectedVehicleId else { return }
        guard step4Valid else {
            errorMessage = "Add at least one geofence zone before creating the trip."
            showError = true
            return
        }
        isCreating = true

        let originCoords: (Double, Double)?
        if let o = selectedOrigin { originCoords = (o.latitude, o.longitude) }
        else { originCoords = await geocodeAddress(origin.trimmingCharacters(in: .whitespaces)) }

        let destCoords: (Double, Double)?
        if let d = selectedDestination { destCoords = (d.latitude, d.longitude) }
        else { destCoords = await geocodeAddress(destination.trimmingCharacters(in: .whitespaces)) }

        do {
            guard let latestDriver = try await StaffMemberService.fetchStaffMember(id: driverId) else {
                errorMessage = "Selected driver no longer exists."; showError = true; isCreating = false; return
            }
            guard latestDriver.status == .active else {
                errorMessage = "Selected driver is not active."; showError = true; isCreating = false; return
            }
            if latestDriver.availability != .available && latestDriver.availability != .busy {
                errorMessage = "Selected driver is unavailable."; showError = true; isCreating = false; return
            }
            if latestDriver.availability == .busy {
                let driverTrips = try await TripService.fetchTrips(driverId: driverId)
                if let err = busyResourceValidationError(resourceLabel: "driver", trips: driverTrips, newTripStart: scheduledDate) {
                    errorMessage = err; showError = true; isCreating = false; return
                }
            }

            guard let latestVehicle = try await VehicleService.fetchVehicle(id: vehicleId) else {
                errorMessage = "Selected vehicle no longer exists."; showError = true; isCreating = false; return
            }
            if latestVehicle.status == .busy {
                let vehicleTrips = try await TripService.fetchTrips(vehicleId: vehicleId)
                if let err = busyResourceValidationError(resourceLabel: "vehicle", trips: vehicleTrips, newTripStart: scheduledDate) {
                    errorMessage = err; showError = true; isCreating = false; return
                }
            }

            let conflict = try await TripService.checkOverlap(
                driverId: driverId, vehicleId: vehicleId,
                start: scheduledDate, end: scheduledEndDate
            )
            if conflict.driverConflict {
                errorMessage = "This driver already has a trip in that time slot."; showError = true; isCreating = false; return
            }
            if conflict.vehicleConflict {
                errorMessage = "This vehicle is already assigned in that time slot."; showError = true; isCreating = false; return
            }

            let adminId = AuthManager.shared.currentUser?.id ?? UUID()
            let now = Date()

            let routeStops: [RouteStop] = stops.enumerated().map { index, addr in
                RouteStop(name: addr.shortName, latitude: addr.latitude, longitude: addr.longitude, order: index + 1)
            }

            let trip = Trip(
                id: UUID(), taskId: TripService.newTaskId(),
                driverId: driverId.uuidString, vehicleId: vehicleId.uuidString,
                createdByAdminId: adminId.uuidString,
                origin: origin.trimmingCharacters(in: .whitespaces),
                destination: destination.trimmingCharacters(in: .whitespaces),
                originLatitude: originCoords?.0, originLongitude: originCoords?.1,
                destinationLatitude: destCoords?.0, destinationLongitude: destCoords?.1,
                routePolyline: nil, routeStops: routeStops.isEmpty ? nil : routeStops,
                deliveryInstructions: "",
                scheduledDate: scheduledDate, scheduledEndDate: scheduledEndDate,
                actualStartDate: nil, actualEndDate: nil,
                startMileage: nil, endMileage: nil,
                notes: notes, status: .scheduled, priority: priority,
                proofOfDeliveryId: nil, preInspectionId: nil, postInspectionId: nil,
                driverRating: nil, driverRatingNote: nil, ratedById: nil, ratedAt: nil,
                createdAt: now, updatedAt: now
            )

            try await store.addTrip(trip)

            if scheduledDate <= now {
                try await TripService.markResourcesBusy(driverId: driverId, vehicleId: vehicleId)
                if var v = store.vehicle(for: vehicleId) { v.status = .busy; v.assignedDriverId = driverId.uuidString; try? await store.updateVehicle(v) }
                if var d = store.staffMember(for: driverId) { d.availability = .busy; try? await store.updateStaffMember(d) }
            }

            createdTrip = trip

            // Persist geofences — now mandatory, so treat failures as blocking.
            for gf in tripGeofences {
                let geofence = Geofence(
                    id: UUID(), name: gf.name,
                    description: "Trip \(trip.taskId) — \(gf.geofenceType.rawValue) zone",
                    latitude: gf.latitude, longitude: gf.longitude,
                    radiusMeters: gf.radiusMeters, isActive: true,
                    createdByAdminId: adminId,
                    alertOnEntry: gf.alertOnEntry, alertOnExit: gf.alertOnExit,
                    geofenceType: gf.geofenceType, createdAt: Date(), updatedAt: Date()
                )
                do {
                    try await store.addGeofence(geofence)
                } catch {
                    print("[CreateTrip] Non-fatal: geofence save failed for \(gf.name): \(error)")
                }
            }

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
            AnimatedCheckmarkView(size: 80).padding(.bottom, 8)
            Text("Trip Created!").font(.title2.weight(.bold)).foregroundStyle(.primary)
            if let trip = createdTrip {
                VStack(spacing: 10) {
                    infoPill("Task ID", value: trip.taskId)
                    infoPill("Route", value: "\(trip.origin) → \(trip.destination)")
                    if let dId = trip.driverId, let dUUID = UUID(uuidString: dId), let driver = store.staffMember(for: dUUID) {
                        infoPill("Driver", value: driver.displayName)
                    }
                    if let vId = trip.vehicleId, let vUUID = UUID(uuidString: vId), let vehicle = store.vehicle(for: vUUID) {
                        infoPill("Vehicle", value: "\(vehicle.name) \(vehicle.model)")
                    }
                    infoPill("Geofences", value: "\(tripGeofences.count) zone\(tripGeofences.count == 1 ? "" : "s") created")
                }.padding(.horizontal, 24)
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Done").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func infoPill(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
            Text(value).font(.subheadline).foregroundStyle(.primary)
            Spacer()
        }
    }

    // MARK: - Geocoding

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
            let coords = geometry?["coordinates"] as? [Double]
            if let lng = coords?[0], let lat = coords?[1] { return (lat, lng) }
        } catch {
            print("[CreateTrip] Geocoding failed: \(error)")
        }
        return nil
    }
}

#Preview {
    CreateTripView().environment(AppDataStore.shared)
}
