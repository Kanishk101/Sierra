# PhaseMap1 - Driver Navigation: Compile Fix + SOS + Voice + Add Stop

## Context
Sierra iOS app. SwiftUI + MVVM + Swift Concurrency.
Repo: Kanishk101/Sierra, main branch.
Mapbox packages from mapbox-navigation-ios (main branch): MapboxNavigationCore, MapboxNavigationUIKit, MapboxDirections.
MapboxMaps is a TRANSITIVE dependency only — it is NOT directly linked as a target product.

## Read these files first — mandatory before writing anything
- Sierra/Driver/Views/TripNavigationView.swift
- Sierra/Driver/Views/NavigationHUDOverlay.swift
- Sierra/Driver/Views/TripNavigationContainerView.swift
- Sierra/Driver/Views/SOSAlertSheet.swift
- Sierra/Driver/Views/IncidentReportSheet.swift
- Sierra/Driver/ViewModels/TripNavigationCoordinator.swift

## Fix 1 — TripNavigationView import MapboxMaps (COMPILE ERROR)

TripNavigationView.swift currently has:
  import MapboxMaps

MapboxMaps is not directly linked as a target product — it is only a transitive dependency.
This causes a compile error: "No such module MapboxMaps".

Fix: Change the import strategy. MapboxMaps types (MapView, MapInitOptions, CameraOptions,
PolylineAnnotation, etc.) are re-exported through MapboxNavigationCore in SDK v3.

Replace:
  import MapboxMaps

With:
  import MapboxNavigationCore

If any MapboxMaps types still cause "cannot find type in scope" errors after this change,
wrap them in the existing MapboxMaps re-export. All MapView, MapInitOptions, CameraOptions,
PolylineAnnotation, StyleColor, PolylineAnnotationManager types are available via MapboxNavigationCore.

Also check if MapboxDirections import is needed or is also re-exported. Keep only imports
that are actually required by the file.

## Fix 2 — Wire SOS Button to SOSAlertSheet

Read NavigationHUDOverlay.swift. The SOS button currently does nothing (empty closure).
Read SOSAlertSheet.swift to understand its init signature.

Add to NavigationHUDOverlay:
  @State private var showSOSAlert = false

Change the SOS action button from empty closure to:
  showSOSAlert = true

Add to NavigationHUDOverlay body (alongside existing sheet and alert modifiers):
  .sheet(isPresented: $showSOSAlert) {
    SOSAlertSheet(
      tripId: coordinator.trip.id,
      vehicleId: UUID(uuidString: coordinator.trip.vehicleId ?? "") ?? UUID(),
      driverId: AuthManager.shared.currentUser?.id ?? UUID()
    )
  }

Check SOSAlertSheet.swift for the exact parameter names and types before writing this.

## Fix 3 — Wire Report Incident Button to IncidentReportSheet

NavigationHUDOverlay currently has no Report Incident button.
Read IncidentReportSheet.swift for its init signature.

Add to NavigationHUDOverlay:
  @State private var showIncidentReport = false

In the actionBar, add a Report Incident button between SOS and Add Stop:
  actionButton("Incident", icon: "exclamationmark.triangle.fill", color: .orange) {
    showIncidentReport = true
  }

Add sheet:
  .sheet(isPresented: $showIncidentReport) {
    IncidentReportSheet(tripId: coordinator.trip.id)
  }

Check IncidentReportSheet.swift for exact parameter names.

## Fix 4 — Add Stop: Actually Add Waypoint and Rebuild Route

Read NavigationHUDOverlay.swift addStopSheet section.
Currently it geocodes the address correctly (500ms debounce, correct API call) but when the
user taps a result, it just closes the sheet without adding the stop.

In TripNavigationCoordinator.swift, add a method:
  func addStop(latitude: Double, longitude: Double, name: String) async {
    // Reset hasBuiltRoutes so buildRoutes() will run again
    hasBuiltRoutes = false
    // TODO: In a full implementation, waypoints would be stored and passed to buildRoutes
    // For now, just rebuild the route (the coordinator uses origin/destination from the trip)
    await buildRoutes()
  }

In NavigationHUDOverlay, when the user taps a geocoded stop result:
  Button {
    let result = result  // capture
    Task {
      await coordinator.addStop(
        latitude: result.latitude,
        longitude: result.longitude,
        name: result.name
      )
    }
    showAddStop = false
  } label: { ... }

## Fix 5 — Voice Guidance via AVSpeechSynthesizer

Read TripNavigationContainerView.swift.

Add to TripNavigationContainerView:
  import AVFoundation (at file top)
  @State private var lastSpokenInstruction = ""
  private let speechSynthesizer = AVSpeechSynthesizer()

Add to the body ZStack, after existing modifiers:
  .onChange(of: coordinator.currentStepInstruction) { _, newInstruction in
    guard !newInstruction.isEmpty, newInstruction != lastSpokenInstruction else { return }
    lastSpokenInstruction = newInstruction
    speechSynthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: newInstruction)
    utterance.rate = 0.52
    utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
    speechSynthesizer.speak(utterance)
  }

This gives the driver voice turn-by-turn guidance. No API calls. No Mapbox SDK dependency.

## Rules
- Do NOT add any new SPM package imports beyond what is already linked
- Read every file before modifying
- Only additive changes — nothing existing removed
- Check exact init signatures from the actual files before wiring sheets

## Output
Update TripNavigationView.swift, NavigationHUDOverlay.swift, TripNavigationContainerView.swift,
TripNavigationCoordinator.swift. Commit to main branch.
