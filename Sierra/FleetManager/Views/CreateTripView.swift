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
/// Phase 13: UI only — all state and logic in CreateTripViewModel.
struct CreateTripView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppDataStore.self) private var store

    @State private var vm = CreateTripViewModel()
    @State private var showRoutePinEditor = false
    @State private var stopEditMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    stepIndicator.padding(.top, 20).padding(.bottom, 16)
                    if vm.showSuccess {
                        successCard
                    } else {
                        switch vm.currentStep {
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !vm.showSuccess { Button("Cancel") { dismiss() } }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if vm.currentStep > 1 && !vm.showSuccess {
                        Button { withAnimation { vm.currentStep -= 1 } } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").font(.caption)
                                Text("Back")
                            }
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if vm.currentStep == 1 && !vm.showSuccess && !vm.stops.isEmpty {
                        Button(stopEditMode == .active ? "Done" : "Reorder Stops") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                stopEditMode = stopEditMode == .active ? .inactive : .active
                            }
                        }
                    }

                    if let action = primaryToolbarAction {
                        Button(action.title) {
                            action.handler()
                        }
                        .fontWeight(.semibold)
                        .disabled(!action.isEnabled)
                    }
                }
            }
        }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "An unknown error occurred.")
        }
    }

    private var primaryToolbarAction: (title: String, isEnabled: Bool, handler: () -> Void)? {
        guard !vm.showSuccess else { return nil }

        switch vm.currentStep {
        case 1:
            return ("Next", vm.step1Valid, { withAnimation(.easeInOut) { vm.currentStep = 2 } })
        case 2:
            return ("Next", vm.step2Valid, { withAnimation(.easeInOut) { vm.currentStep = 3 } })
        case 3:
            return ("Next", vm.step3Valid, { withAnimation(.easeInOut) { vm.currentStep = 4 } })
        default:
            return nil
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(1...4, id: \.self) { step in
                Circle()
                    .fill(step <= vm.currentStep ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .overlay {
                        if step < vm.currentStep {
                            Image(systemName: "checkmark").font(SierraFont.scaled(7, weight: .bold)).foregroundStyle(.white)
                        }
                    }
                if step < 4 {
                    Rectangle().fill(step < vm.currentStep ? Color.orange : Color.gray.opacity(0.2)).frame(height: 2).frame(maxWidth: 60)
                }
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 1: Trip Details

    private var step1View: some View {
        VStack(spacing: 0) {
            Form {
                Section("Route") {
                    HStack(spacing: 10) {
                        Button { vm.showOriginSearch = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "circle.fill").font(SierraFont.scaled(10)).foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Origin").font(.caption).foregroundStyle(.secondary)
                                    Text(vm.origin.isEmpty ? "Search origin address…" : vm.origin)
                                        .font(.subheadline).foregroundStyle(vm.origin.isEmpty ? .tertiary : .primary).lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if vm.selectedOrigin != nil {
                            Button {
                                vm.setOrigin(nil)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(SierraFont.scaled(16))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(vm.stops) { stop in
                        let index = (vm.stops.firstIndex(where: { $0.id == stop.id }) ?? 0) + 1
                        HStack(spacing: 12) {
                            Image(systemName: "\(index).circle.fill").font(SierraFont.scaled(14)).foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stop \(index)").font(.caption).foregroundStyle(.secondary)
                                Text(stop.shortName).font(.subheadline).foregroundStyle(.primary)
                            }
                            Spacer()
                            Button { vm.removeStop(id: stop.id) } label: {
                                Image(systemName: "xmark.circle.fill").font(SierraFont.scaled(16)).foregroundStyle(.red.opacity(0.7))
                            }.buttonStyle(.plain)
                        }
                    }
                    .onMove(perform: vm.moveStops)

                    Button { vm.showStopSearch = true } label: {
                        Label("Add Stop", systemImage: "plus.circle").font(.subheadline).foregroundStyle(.orange)
                    }

                    HStack(spacing: 10) {
                        Button { vm.showDestinationSearch = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill").font(SierraFont.scaled(14)).foregroundStyle(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Destination").font(.caption).foregroundStyle(.secondary)
                                    Text(vm.destination.isEmpty ? "Search destination address…" : vm.destination)
                                        .font(.subheadline).foregroundStyle(vm.destination.isEmpty ? .tertiary : .primary).lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if vm.selectedDestination != nil {
                            Button {
                                vm.setDestination(nil)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(SierraFont.scaled(16))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        showRoutePinEditor = true
                    } label: {
                        Label("Edit Route Pins on Map", systemImage: "hand.draw.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }

                if vm.selectedOrigin != nil || vm.selectedDestination != nil {
                    Section("Route Preview") { routeMapPreview }
                }

                Section("Schedule") {
                    DatePicker("Departure *", selection: $vm.scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    Picker("Priority", selection: $vm.priority) {
                        ForEach(TripPriority.allCases, id: \.self) { p in Text(p.rawValue).tag(p) }
                    }
                }
                Section("Notes") {
                    TextEditor(text: $vm.notes).frame(minHeight: 60)
                }
            }
            .scrollContentBackground(.hidden)
            .environment(\.editMode, $stopEditMode)
            .onChange(of: vm.scheduledDate) { _, newDate in vm.scheduledEndDate = newDate.addingTimeInterval(3600 * 8) }
            .sheet(isPresented: $vm.showOriginSearch) {
                AddressSearchSheet(placeholder: "Search origin address…") { result in
                    vm.setOrigin(result)
                }
            }
            .sheet(isPresented: $vm.showDestinationSearch) {
                AddressSearchSheet(placeholder: "Search destination address…", showMyLocation: false) { result in
                    vm.setDestination(result)
                }
            }
            .sheet(isPresented: $vm.showStopSearch) {
                AddressSearchSheet(placeholder: "Search stop address…") { result in
                    vm.addStop(result)
                }
            }
            .sheet(isPresented: $showRoutePinEditor) {
                RoutePinEditorSheet(
                    origin: vm.selectedOrigin,
                    destination: vm.selectedDestination,
                    stops: vm.stops
                ) { origin, destination, stops in
                    vm.applyRoutePins(origin: origin, destination: destination, stops: stops)
                }
            }
        }
    }

    // MARK: - Route Map Preview

    private var routeMapPreview: some View {
        Map {
            if let o = vm.selectedOrigin {
                Annotation(o.shortName, coordinate: o.coordinate) {
                    Image(systemName: "circle.fill").font(SierraFont.scaled(12)).foregroundStyle(.green).background(.white, in: Circle()).shadow(radius: 2)
                }
            }
            ForEach(Array(vm.stops.enumerated()), id: \.element.id) { index, stop in
                Annotation("Stop \(index + 1)", coordinate: stop.coordinate) {
                    Text("\(index + 1)").font(SierraFont.scaled(10, weight: .bold)).foregroundStyle(.white).frame(width: 22, height: 22).background(.orange, in: Circle()).shadow(radius: 2)
                }
            }
            if let d = vm.selectedDestination {
                Annotation(d.shortName, coordinate: d.coordinate) {
                    Image(systemName: "mappin.circle.fill").font(SierraFont.scaled(16)).foregroundStyle(.red).background(.white, in: Circle()).shadow(radius: 2)
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
                    Image(systemName: "person.slash.fill").font(SierraFont.scaled(36)).foregroundStyle(.gray.opacity(0.4))
                    Text("No available drivers").font(SierraFont.scaled(16, weight: .semibold)).foregroundStyle(.secondary)
                    Text("Ensure drivers are approved and set to Available.").font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                    Spacer()
                }.padding(.horizontal, 30)
            } else {
                Text("Select Driver").font(SierraFont.scaled(18, weight: .bold)).padding(.top, 4)
                List {
                    ForEach(drivers) { driver in
                        Button { vm.selectedDriverId = driver.id } label: {
                            HStack(spacing: 12) {
                                Circle().fill(Color.blue.opacity(0.12)).frame(width: 40, height: 40)
                                    .overlay(Text(driver.initials).font(SierraFont.scaled(14, weight: .bold)).foregroundStyle(.blue))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(driver.displayName).font(.subheadline).foregroundStyle(.primary)
                                    Text(driver.phone ?? "No phone").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if vm.selectedDriverId == driver.id {
                                    Image(systemName: "checkmark.circle.fill").font(SierraFont.scaled(20)).foregroundStyle(.orange)
                                }
                            }
                        }
                        .listRowBackground(vm.selectedDriverId == driver.id ? Color.orange.opacity(0.06) : Color.clear)
                    }
                }.listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Step 3: Assign Vehicle

    private var step3View: some View {
        VStack(spacing: 0) {
            let vehicles = store.availableVehicles()
            if vehicles.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "car.fill").font(SierraFont.scaled(36)).foregroundStyle(.gray.opacity(0.4))
                    Text("No available vehicles").font(SierraFont.scaled(16, weight: .semibold)).foregroundStyle(.secondary)
                    Text("Ensure vehicles are idle and not currently assigned.").font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                    Spacer()
                }.padding(.horizontal, 30)
            } else {
                Text("Select Vehicle").font(SierraFont.scaled(18, weight: .bold)).padding(.top, 4)
                List {
                    ForEach(vehicles) { vehicle in
                        Button { vm.selectedVehicleId = vehicle.id } label: {
                            HStack(spacing: 12) {
                                Circle().fill(colorDot(vehicle.color)).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(vehicle.name) \(vehicle.model)").font(.subheadline).foregroundStyle(.primary)
                                    HStack(spacing: 8) {
                                        Text(vehicle.licensePlate)
                                            .font(SierraFont.scaled(12, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                                            .padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.1), in: Capsule())
                                        Text(vehicle.fuelType.description).font(.caption2).foregroundStyle(.secondary)
                                        Text("· \(vehicle.seatingCapacity) seats").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if vm.selectedVehicleId == vehicle.id {
                                    Image(systemName: "checkmark.circle.fill").font(SierraFont.scaled(20)).foregroundStyle(.orange)
                                }
                            }
                        }
                        .listRowBackground(vm.selectedVehicleId == vehicle.id ? Color.orange.opacity(0.06) : Color.clear)
                    }
                }.listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Step 4: Add Geofences

    private var step4View: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Add Geofences").font(SierraFont.scaled(18, weight: .bold))
                Text("Define at least one monitoring zone for this trip").font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 8).padding(.bottom, 12)

            List {
                Section {
                    let suggestions = vm.buildSuggestions()
                    if suggestions.isEmpty {
                        Text("Select origin and destination in Step 1 to get zone suggestions.")
                            .font(.caption).foregroundStyle(.tertiary)
                    } else {
                        ForEach(suggestions, id: \.0) { name, lat, lng in
                            let alreadyAdded = vm.hasGeofence(latitude: lat, longitude: lng)
                            Button {
                                vm.addGeofence(name: name, latitude: lat, longitude: lng)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(alreadyAdded ? .green : .teal).font(SierraFont.scaled(18))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name).font(.subheadline).foregroundStyle(.primary)
                                        Text("Tap to add 500m monitoring zone").font(.caption2).foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    if alreadyAdded { Text("Added").font(.caption.weight(.semibold)).foregroundStyle(.green) }
                                }
                            }.buttonStyle(.plain).disabled(alreadyAdded)
                        }
                    }
                } header: { Text("Suggested from Route") }

                if !vm.tripGeofences.isEmpty {
                    Section {
                        ForEach($vm.tripGeofences) { $gf in
                            geofenceConfigRow(gf: $gf)
                        }
                    } header: {
                        HStack {
                            Text("Added Geofences")
                            Spacer()
                            Text("\(vm.tripGeofences.count) zone\(vm.tripGeofences.count == 1 ? "" : "s")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.listStyle(.insetGrouped).scrollContentBackground(.hidden)

            VStack(spacing: 6) {
                if !vm.step4Valid {
                    Text("Add at least one geofence to continue").font(.caption).foregroundStyle(.secondary)
                }
                Button { Task { await vm.createTrip(store: store) } } label: {
                    HStack {
                        if vm.isCreating { ProgressView().scaleEffect(0.9).tint(.white) }
                        else { Text("Create Trip"); Image(systemName: "checkmark") }
                    }
                    .font(SierraFont.scaled(16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(vm.step4Valid ? Color.green : Color.gray.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }.disabled(vm.isCreating || !vm.step4Valid)
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: - Geofence Config Row

    @ViewBuilder
    private func geofenceConfigRow(gf: Binding<GeofenceCandidate>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                geofenceTypeIcon(gf.wrappedValue.geofenceType)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gf.wrappedValue.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text("\(Int(gf.wrappedValue.radiusMeters))m • \(gf.wrappedValue.geofenceType.rawValue)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    let id = gf.wrappedValue.id
                    DispatchQueue.main.async {
                        vm.removeGeofence(id: id)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.red.opacity(0.7))
                }.buttonStyle(.plain)
            }.padding(.vertical, 8)

            Divider().padding(.leading, 38)

            VStack(spacing: 6) {
                HStack {
                    Text("Radius").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(gf.wrappedValue.radiusMeters)) m")
                        .font(.system(.caption, design: .monospaced).weight(.semibold)).foregroundStyle(.orange)
                }
                Slider(value: gf.radiusMeters, in: 100...5000, step: 50).tint(.orange)
                HStack {
                    Text("100m").font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("5km").font(.caption2).foregroundStyle(.tertiary)
                }
            }.padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Zone Type").font(.caption).foregroundStyle(.secondary)
                geofenceTypeSelector(gf: gf)
            }.padding(.top, 8)

            VStack(spacing: 10) {
                alertToggleRow(title: "Entry Alert", icon: "arrow.down.circle", isOn: gf.alertOnEntry)
                alertToggleRow(title: "Exit Alert", icon: "arrow.up.circle", isOn: gf.alertOnExit)
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func geofenceTypeSelector(gf: Binding<GeofenceCandidate>) -> some View {
        Menu {
            ForEach(GeofenceType.allCases, id: \.self) { type in
                Button {
                    gf.wrappedValue.geofenceType = type
                } label: {
                    Label(type.rawValue, systemImage: geofenceTypeIconName(type))
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: geofenceTypeIconName(gf.wrappedValue.geofenceType))
                    .font(.caption.weight(.semibold))
                Text(gf.wrappedValue.geofenceType.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func alertToggleRow(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.appOrange)
                .accessibilityLabel(title)
                .accessibilityHint("Turns \(title) on or off")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func geofenceTypeIcon(_ type: GeofenceType) -> some View {
        Image(systemName: geofenceTypeIconName(type))
            .font(SierraFont.scaled(18)).foregroundStyle(geofenceTypeColor(type))
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

    // MARK: - Success Card

    private var successCard: some View {
        VStack(spacing: 24) {
            Spacer()
            AnimatedCheckmarkView(size: 80).padding(.bottom, 8)
            Text("Trip Created!").font(.title2.weight(.bold)).foregroundStyle(.primary)
            if let trip = vm.createdTrip {
                VStack(spacing: 10) {
                    infoPill("Task ID", value: trip.taskId)
                    infoPill("Route", value: "\(trip.origin) → \(trip.destination)")
                    if let dId = trip.driverId, let dUUID = UUID(uuidString: dId), let driver = store.staffMember(for: dUUID) {
                        infoPill("Driver", value: driver.displayName)
                    }
                    if let vId = trip.vehicleId, let vUUID = UUID(uuidString: vId), let vehicle = store.vehicle(for: vUUID) {
                        infoPill("Vehicle", value: "\(vehicle.name) \(vehicle.model)")
                    }
                    infoPill("Geofences", value: "\(vm.tripGeofences.count) zone\(vm.tripGeofences.count == 1 ? "" : "s") created")
                }.padding(.horizontal, 24)
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Done").font(SierraFont.scaled(17, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }.padding(.horizontal, 20).padding(.bottom, 20)
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
}

// MARK: - Route Pin Editor

private struct RoutePinEditorSheet: View {
    let onApply: (GeocodedAddress?, GeocodedAddress?, [GeocodedAddress]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draftOrigin: GeocodedAddress?
    @State private var draftDestination: GeocodedAddress?
    @State private var draftStops: [GeocodedAddress]

    init(
        origin: GeocodedAddress?,
        destination: GeocodedAddress?,
        stops: [GeocodedAddress],
        onApply: @escaping (GeocodedAddress?, GeocodedAddress?, [GeocodedAddress]) -> Void
    ) {
        self.onApply = onApply
        _draftOrigin = State(initialValue: origin)
        _draftDestination = State(initialValue: destination)
        _draftStops = State(initialValue: stops)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                RoutePinEditorMapView(
                    origin: draftOrigin,
                    destination: draftDestination,
                    stops: draftStops,
                    onLongPressDrop: { coordinate in
                        handleLongPressDrop(at: coordinate)
                    },
                    onMoveOrigin: { coordinate in
                        draftOrigin = movedAddress(
                            from: draftOrigin,
                            fallbackShortName: "Origin Pin",
                            coordinate: coordinate
                        )
                    },
                    onMoveDestination: { coordinate in
                        draftDestination = movedAddress(
                            from: draftDestination,
                            fallbackShortName: "Destination Pin",
                            coordinate: coordinate
                        )
                    },
                    onMoveStop: { stopId, coordinate in
                        guard let index = draftStops.firstIndex(where: { $0.id == stopId }) else { return }
                        draftStops[index] = movedAddress(
                            from: draftStops[index],
                            fallbackShortName: draftStops[index].shortName,
                            coordinate: coordinate
                        )
                    },
                    onSelectStop: { stopId in
                        _ = stopId
                    }
                )
                .frame(height: 350)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    Text("Long-press map to drop pins. First = Origin, second = Destination, then Stops.")
                        .font(SierraFont.scaled(11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(10)
                }

                HStack(spacing: 8) {
                    simpleActionButton("Clear Origin", tint: .green) {
                        draftOrigin = nil
                    }
                    simpleActionButton("Clear Destination", tint: .red) {
                        draftDestination = nil
                    }
                }

                if !draftStops.isEmpty {
                    stopOrderList
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("Edit Route Pins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(draftOrigin, draftDestination, draftStops)
                        dismiss()
                    }
                }
            }
        }
    }

    private var stopOrderList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stop Order")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Drag to reorder. Swipe left to remove.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            List {
                ForEach(Array(draftStops.enumerated()), id: \.element.id) { index, stop in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.orange, in: Circle())

                        Text(stop.shortName)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            draftStops.removeAll { $0.id == stop.id }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .onMove { source, destination in
                    draftStops.move(fromOffsets: source, toOffset: destination)
                }
            }
            .frame(height: min(CGFloat(draftStops.count) * 46 + 24, 220))
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
            .listStyle(.plain)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func simpleActionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(SierraFont.scaled(12, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func handleLongPressDrop(at coordinate: CLLocationCoordinate2D) {
        if draftOrigin == nil {
            draftOrigin = movedAddress(
                from: draftOrigin,
                fallbackShortName: "Origin",
                coordinate: coordinate
            )
            return
        }
        if draftDestination == nil {
            draftDestination = movedAddress(
                from: draftDestination,
                fallbackShortName: "Destination",
                coordinate: coordinate
            )
            return
        }

        let next = draftStops.count + 1
        let stop = GeocodedAddress(
            displayName: "Stop \(next) (\(formatCoordinate(coordinate.latitude)), \(formatCoordinate(coordinate.longitude)))",
            shortName: "Stop \(next)",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        draftStops.append(stop)
    }

    private func movedAddress(
        from existing: GeocodedAddress?,
        fallbackShortName: String,
        coordinate: CLLocationCoordinate2D
    ) -> GeocodedAddress {
        let short: String
        if let existing,
           !existing.shortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            short = existing.shortName
        } else {
            short = fallbackShortName
        }
        return GeocodedAddress(
            displayName: "\(short) (\(formatCoordinate(coordinate.latitude)), \(formatCoordinate(coordinate.longitude)))",
            shortName: short,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    private func formatCoordinate(_ value: Double) -> String {
        String(format: "%.5f", value)
    }
}

private struct RoutePinEditorMapView: UIViewRepresentable {
    var origin: GeocodedAddress?
    var destination: GeocodedAddress?
    var stops: [GeocodedAddress]
    var onLongPressDrop: (CLLocationCoordinate2D) -> Void
    var onMoveOrigin: (CLLocationCoordinate2D) -> Void
    var onMoveDestination: (CLLocationCoordinate2D) -> Void
    var onMoveStop: (UUID, CLLocationCoordinate2D) -> Void
    var onSelectStop: (UUID?) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = false
        mapView.pointOfInterestFilter = .includingAll
        mapView.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
                latitudinalMeters: 2_600_000,
                longitudinalMeters: 2_600_000
            ),
            animated: false
        )
        context.coordinator.renderAnnotations(on: mapView)
        context.coordinator.installLongPressRecognizer(on: mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.renderAnnotations(on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RoutePinEditorMapView
        private var hasAppliedInitialFit = false

        init(parent: RoutePinEditorMapView) {
            self.parent = parent
        }

        func renderAnnotations(on mapView: MKMapView) {
            let existingPins = mapView.annotations.compactMap { $0 as? RoutePinAnnotation }
            mapView.removeAnnotations(existingPins)

            var pins: [RoutePinAnnotation] = []

            if let origin = parent.origin {
                pins.append(
                    RoutePinAnnotation(
                        role: .origin,
                        stopId: nil,
                        stopIndex: nil,
                        title: "Origin",
                        coordinate: origin.coordinate
                    )
                )
            }
            for (index, stop) in parent.stops.enumerated() {
                pins.append(
                    RoutePinAnnotation(
                        role: .stop,
                        stopId: stop.id,
                        stopIndex: index + 1,
                        title: "Stop \(index + 1)",
                        coordinate: stop.coordinate
                    )
                )
            }
            if let destination = parent.destination {
                pins.append(
                    RoutePinAnnotation(
                        role: .destination,
                        stopId: nil,
                        stopIndex: nil,
                        title: "Destination",
                        coordinate: destination.coordinate
                    )
                )
            }

            mapView.addAnnotations(pins)

            if !hasAppliedInitialFit {
                hasAppliedInitialFit = true
                fitToAnnotations(on: mapView, pins: pins)
            }
        }

        func installLongPressRecognizer(on mapView: MKMapView) {
            let alreadyInstalled = mapView.gestureRecognizers?.contains(where: { $0.name == "route-pin-drop-long-press" }) ?? false
            guard !alreadyInstalled else { return }
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            recognizer.minimumPressDuration = 0.45
            recognizer.name = "route-pin-drop-long-press"
            mapView.addGestureRecognizer(recognizer)
        }

        private func fitToAnnotations(on mapView: MKMapView, pins: [RoutePinAnnotation]) {
            guard !pins.isEmpty else { return }
            let coords = pins.map(\.coordinate)
            let lats = coords.map(\.latitude)
            let lngs = coords.map(\.longitude)
            guard let minLat = lats.min(),
                  let maxLat = lats.max(),
                  let minLng = lngs.min(),
                  let maxLng = lngs.max() else { return }

            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.8, 0.04),
                longitudeDelta: max((maxLng - minLng) * 1.8, 0.04)
            )
            mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard let pin = annotation as? RoutePinAnnotation else { return nil }

            let identifier = "route-pin"
            let marker = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: pin, reuseIdentifier: identifier)

            marker.annotation = pin
            marker.canShowCallout = false
            marker.isDraggable = true
            marker.displayPriority = .required
            marker.glyphText = nil
            marker.glyphImage = nil

            switch pin.role {
            case .origin:
                marker.markerTintColor = .systemGreen
                marker.glyphImage = UIImage(systemName: "circle.fill")
            case .destination:
                marker.markerTintColor = .systemRed
                marker.glyphImage = UIImage(systemName: "mappin.circle.fill")
            case .stop:
                marker.markerTintColor = .systemOrange
                if let stopIndex = pin.stopIndex {
                    marker.glyphText = "\(stopIndex)"
                } else {
                    marker.glyphImage = UIImage(systemName: "circle.fill")
                }
            }

            return marker
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let pin = view.annotation as? RoutePinAnnotation else {
                parent.onSelectStop(nil)
                return
            }
            if pin.role == .stop, let stopId = pin.stopId {
                parent.onSelectStop(stopId)
            } else {
                parent.onSelectStop(nil)
            }
        }

        func mapView(
            _ mapView: MKMapView,
            annotationView view: MKAnnotationView,
            didChange newState: MKAnnotationView.DragState,
            fromOldState oldState: MKAnnotationView.DragState
        ) {
            guard let pin = view.annotation as? RoutePinAnnotation else { return }
            guard newState == .ending || newState == .canceling else { return }

            let coordinate = pin.coordinate
            switch pin.role {
            case .origin:
                parent.onMoveOrigin(coordinate)
            case .destination:
                parent.onMoveDestination(coordinate)
            case .stop:
                if let stopId = pin.stopId {
                    parent.onMoveStop(stopId, coordinate)
                    parent.onSelectStop(stopId)
                }
            }
            view.setDragState(.none, animated: false)
        }

        @objc
        private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began else { return }
            guard let mapView = recognizer.view as? MKMapView else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onLongPressDrop(coordinate)
        }
    }
}

private final class RoutePinAnnotation: NSObject, MKAnnotation {
    enum Role {
        case origin
        case destination
        case stop
    }

    let role: Role
    let stopId: UUID?
    let stopIndex: Int?
    let title: String?
    dynamic var coordinate: CLLocationCoordinate2D

    init(
        role: Role,
        stopId: UUID?,
        stopIndex: Int?,
        title: String,
        coordinate: CLLocationCoordinate2D
    ) {
        self.role = role
        self.stopId = stopId
        self.stopIndex = stopIndex
        self.title = title
        self.coordinate = coordinate
    }
}

#Preview {
    CreateTripView().environment(AppDataStore.shared)
}
