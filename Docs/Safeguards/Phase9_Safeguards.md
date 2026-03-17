# Phase 9 Safeguards — Dashboard & Reports
## Attach these instructions at the END of your Phase 9 prompt session before Claude writes any code.

---

## SAFEGUARD 1 — All analytics must be computed from AppDataStore in-memory arrays, never direct Supabase queries

DashboardHomeView, AnalyticsDashboardView, and ReportsView must compute all statistics from data already loaded in AppDataStore (vehicles, trips, staffMembers, maintenanceTasks, etc.). They must NOT make their own independent Supabase queries.

The only acceptable Supabase queries in this phase:
  - DriverHistoryView loading a specific driver's trip history (scoped to one driver's rows)
  - ReportsView loading fuel_logs and trip_expenses for a date range (not loaded elsewhere)
  - The rating update in TripService.rateDriver()

Everything else — vehicle counts, trip counts, active driver counts, maintenance summaries — is derived from what's already in AppDataStore. This means zero extra DB queries for the dashboard to load.

## SAFEGUARD 2 — Date range filtering must happen in Swift, not via new Supabase queries

When the FM changes the date range picker (Last 7 / 30 / 90 days) in AnalyticsDashboardView, the filter must be applied to the existing AppDataStore.trips array in Swift, not by firing a new Supabase query with different date parameters.

Correct:
  var tripsInRange: [Trip] {
    let cutoff = Calendar.current.date(byAdding: .day, value: -selectedDays, to: Date()) ?? Date()
    return appDataStore.trips.filter { $0.createdAt >= cutoff }
  }

Incorrect: re-fetching trips with a new .gte("created_at", value: cutoff) query every time the picker changes.

## SAFEGUARD 3 — ReportsView CSV export must use UIActivityViewController, not write to disk

The export function must generate a CSV string in memory and share it via UIActivityViewController. It must NOT write to the device's file system (no FileManager, no Documents directory writes). Reason: writing to disk requires entitlements, user permission handling, and cleanup. The share sheet handles all of this automatically.

  let csvString = generateCSV(from: trips)
  let activityVC = UIActivityViewController(
    activityItems: [csvString],
    applicationActivities: nil
  )
  present(activityVC, ...)

The CSV string must be generated synchronously from in-memory data — no async operation needed.

## SAFEGUARD 4 — DriverHistoryView must not load ALL trips to filter client-side

Unlike the dashboard which uses cached data, DriverHistoryView loads a specific driver's trip history. This is an acceptable Supabase query BUT it must be scoped:

  .from("trips")
  .select()
  .eq("driver_id", value: driver.id)
  .eq("status", value: "Completed")
  .order("actual_end_date", ascending: false)
  .limit(50)  // CRITICAL: limit to 50 most recent trips

Never load all trips for a driver without a limit. A driver with 500 completed trips would return 500 rows. 50 is sufficient for display; a "Load More" button can paginate if needed.

## SAFEGUARD 5 — Bar chart must use SwiftUI GeometryReader bars, not an external chart library

The vehicle status breakdown chart must be built with pure SwiftUI (GeometryReader + HStack/VStack with color-coded bars). No external dependencies like Charts.framework, swift-charts, or any SPM chart package.

The Charts framework (Apple) is acceptable if the iOS deployment target is 16+. Confirm the project's deployment target before using it. If deployment target is iOS 15, use GeometryReader bars.

## SAFEGUARD 6 — Driver deactivation must show confirmation alert before executing

Deactivating a driver (setting status = Suspended) from DriverHistoryView is irreversible in the immediate session. Always show an Alert with a confirmation:

  Alert(
    title: Text("Deactivate \(driver.name)?"),
    message: Text("This driver will lose access to the app immediately. You can reactivate them from Staff Management."),
    primaryButton: .destructive(Text("Deactivate")) { /* call service */ },
    secondaryButton: .cancel()
  )

Never execute a deactivation from a button tap without this confirmation step.

## SAFEGUARD 7 — Average rating computation must exclude nil ratings

driver_profiles.average_rating and the trips-based average must both exclude trips where driver_rating IS NULL. In Swift:

  let ratedTrips = trips.filter { $0.driverRating != nil }
  let average = ratedTrips.isEmpty ? nil : Double(ratedTrips.compactMap { $0.driverRating }.reduce(0, +)) / Double(ratedTrips.count)

Never divide by trips.count when computing average rating — you'd dilute the average with unrated trips and show a misleadingly low number.

## VERIFICATION CHECKLIST — Before committing

- [ ] Dashboard stats computed from AppDataStore in-memory arrays, zero extra DB queries
- [ ] Date range filter applied in Swift to cached array, not via new Supabase query
- [ ] CSV export uses UIActivityViewController with in-memory string, no file writes
- [ ] DriverHistoryView trip query scoped to one driver with .limit(50)
- [ ] Bar chart uses SwiftUI only (GeometryReader or Apple Charts if iOS 16+)
- [ ] Driver deactivation shows confirmation Alert before service call
- [ ] Average rating computed from non-nil ratings only
