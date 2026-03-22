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
            }
        }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "An unknown error occurred.")
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
                            Image(systemName: "checkmark").font(.system(size: 7, weight: .bold)).foregroundStyle(.white)
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
                    Button { vm.showOriginSearch = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "circle.fill").font(.system(size: 10)).foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Origin").font(.caption).foregroundStyle(.secondary)
                                Text(vm.origin.isEmpty ? "Search origin address…" : vm.origin)
                                    .font(.subheadline).foregroundStyle(vm.origin.isEmpty ? .tertiary : .primary).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)

                    ForEach(Array(vm.stops.enumerated()), id: \.element.id) { index, stop in
                        HStack(spacing: 12) {
                            Image(systemName: "\(index + 1).circle.fill").font(.system(size: 14)).foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stop \(index + 1)").font(.caption).foregroundStyle(.secondary)
                                Text(stop.shortName).font(.subheadline).foregroundStyle(.primary)
                            }
                            Spacer()
                            Button { vm.stops.remove(at: index) } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(.red.opacity(0.7))
                            }.buttonStyle(.plain)
                        }
                    }

                    Button { vm.showStopSearch = true } label: {
                        Label("Add Stop", systemImage: "plus.circle").font(.subheadline).foregroundStyle(.orange)
                    }

                    Button { vm.showDestinationSearch = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill").font(.system(size: 14)).foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Destination").font(.caption).foregroundStyle(.secondary)
                                Text(vm.destination.isEmpty ? "Search destination address…" : vm.destination)
                                    .font(.subheadline).foregroundStyle(vm.destination.isEmpty ? .tertiary : .primary).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
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
            .onChange(of: vm.scheduledDate) { _, newDate in vm.scheduledEndDate = newDate.addingTimeInterval(3600 * 8) }
            .sheet(isPresented: $vm.showOriginSearch) {
                AddressSearchSheet(placeholder: "Search origin address…") { result in vm.selectedOrigin = result; vm.origin = result.displayName }
            }
            .sheet(isPresented: $vm.showDestinationSearch) {
                AddressSearchSheet(placeholder: "Search destination address…") { result in vm.selectedDestination = result; vm.destination = result.displayName }
            }
            .sheet(isPresented: $vm.showStopSearch) {
                AddressSearchSheet(placeholder: "Search stop address…") { result in vm.stops.append(result) }
            }

            Button { withAnimation(.easeInOut) { vm.currentStep = 2 } } label: {
                HStack {
                    Text("Next: Assign Driver")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!vm.step1Valid).opacity(vm.step1Valid ? 1 : 0.5)
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: - Route Map Preview

    private var routeMapPreview: some View {
        Map {
            if let o = vm.selectedOrigin {
                Annotation(o.shortName, coordinate: o.coordinate) {
                    Image(systemName: "circle.fill").font(.system(size: 12)).foregroundStyle(.green).background(.white, in: Circle()).shadow(radius: 2)
                }
            }
            ForEach(Array(vm.stops.enumerated()), id: \.element.id) { index, stop in
                Annotation("Stop \(index + 1)", coordinate: stop.coordinate) {
                    Text("\(index + 1)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white).frame(width: 22, height: 22).background(.orange, in: Circle()).shadow(radius: 2)
                }
            }
            if let d = vm.selectedDestination {
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
                }.padding(.horizontal, 30)
            } else {
                Text("Select Driver").font(.system(size: 18, weight: .bold)).padding(.top, 4)
                List {
                    ForEach(drivers) { driver in
                        Button { vm.selectedDriverId = driver.id } label: {
                            HStack(spacing: 12) {
                                Circle().fill(Color.blue.opacity(0.12)).frame(width: 40, height: 40)
                                    .overlay(Text(driver.initials).font(.system(size: 14, weight: .bold)).foregroundStyle(.blue))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(driver.displayName).font(.subheadline).foregroundStyle(.primary)
                                    Text(driver.phone ?? "No phone").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if vm.selectedDriverId == driver.id {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(.orange)
                                }
                            }
                        }
                        .listRowBackground(vm.selectedDriverId == driver.id ? Color.orange.opacity(0.06) : Color.clear)
                    }
                }.listStyle(.plain).scrollContentBackground(.hidden)
            }
            Button { withAnimation(.easeInOut) { vm.currentStep = 3 } } label: {
                HStack { Text("Next: Assign Vehicle"); Image(systemName: "arrow.right") }
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!vm.step2Valid).opacity(vm.step2Valid ? 1 : 0.5)
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: - Step 3: Assign Vehicle

    private var step3View: some View {
        VStack(spacing: 0) {
            let vehicles = store.vehicles.filter { $0.status == .idle }
            if vehicles.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "car.fill").font(.system(size: 36)).foregroundStyle(.gray.opacity(0.4))
                    Text("No available vehicles").font(.system(size: 16, weight: .semibold)).foregroundStyle(.secondary)
                    Text("Ensure vehicles are idle and not currently assigned.").font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                    Spacer()
                }.padding(.horizontal, 30)
            } else {
                Text("Select Vehicle").font(.system(size: 18, weight: .bold)).padding(.top, 4)
                List {
                    ForEach(vehicles) { vehicle in
                        Button { vm.selectedVehicleId = vehicle.id } label: {
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
                                if vm.selectedVehicleId == vehicle.id {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(.orange)
                                }
                            }
                        }
                        .listRowBackground(vm.selectedVehicleId == vehicle.id ? Color.orange.opacity(0.06) : Color.clear)
                    }
                }.listStyle(.plain).scrollContentBackground(.hidden)
            }
            Button { withAnimation(.easeInOut) { vm.currentStep = 4 } } label: {
                HStack { Text("Next: Add Geofences"); Image(systemName: "arrow.right") }
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!vm.step3Valid).opacity(vm.step3Valid ? 1 : 0.5)
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: - Step 4: Add Geofences

    private var step4View: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Add Geofences").font(.system(size: 18, weight: .bold))
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
                            let alreadyAdded = vm.tripGeofences.contains { $0.latitude == lat && $0.longitude == lng }
                            Button {
                                if !alreadyAdded {
                                    vm.tripGeofences.append(GeofenceCandidate(name: name, latitude: lat, longitude: lng))
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(alreadyAdded ? .green : .teal).font(.system(size: 18))
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
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
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
                    Text(gf.wrappedValue.name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    Text("\(Int(gf.wrappedValue.radiusMeters))m • \(gf.wrappedValue.geofenceType.rawValue)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button { vm.tripGeofences.removeAll { $0.id == gf.wrappedValue.id } } label: {
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
                Picker("", selection: gf.geofenceType) {
                    ForEach(GeofenceType.allCases, id: \.self) { type in
                        HStack { Image(systemName: geofenceTypeIconName(type)); Text(type.rawValue) }.tag(type)
                    }
                }.pickerStyle(.segmented)
            }.padding(.top, 8)

            HStack(spacing: 16) {
                Toggle(isOn: gf.alertOnEntry) {
                    Label("Entry Alert", systemImage: "arrow.down.circle").font(.caption)
                }.toggleStyle(.switch).tint(.orange)
                Toggle(isOn: gf.alertOnExit) {
                    Label("Exit Alert", systemImage: "arrow.up.circle").font(.caption)
                }.toggleStyle(.switch).tint(.orange)
            }.padding(.top, 8).padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func geofenceTypeIcon(_ type: GeofenceType) -> some View {
        Image(systemName: geofenceTypeIconName(type))
            .font(.system(size: 18)).foregroundStyle(geofenceTypeColor(type))
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
                Text("Done").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
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

#Preview {
    CreateTripView().environment(AppDataStore.shared)
}
