# PHASE 4 — Driver Module Migration

## Context
Files: `Sierra/Driver/DriverTabView.swift`, `Sierra/Driver/Views/DriverHomeView.swift`, `Sierra/Driver/Views/DriverApplicationSubmittedView.swift`.

Files with **identical SHAs** (no changes needed): `DriverProfilePage1View.swift`, `DriverProfilePage2View.swift`, `DriverProfileSetupView.swift`.

Read Phase 1 for the complete palette and navigation rules. All ViewModels and data logic stay unchanged.

---

## FILE 1: `DriverTabView.swift`

This is the root tab container for the Driver role. Apply:
- `.tint(.orange)` on the `TabView`
- Any placeholder tab backgrounds: `Color(.secondarySystemGroupedBackground).ignoresSafeArea()`
- Remove any dark gradient backgrounds in placeholder tabs
- All icon/text colors: system equivalents

---

## FILE 2: `DriverHomeView.swift` — FULL NATIVE REWRITE

This is a **complete native system-color rewrite**. Every Sierra token is replaced. The navigation in this view is embedded in a tab, so it gets the large morphing title.

### Navigation & toolbar
```swift
// On the ScrollView container:
.navigationTitle("Home")
.navigationBarTitleDisplayMode(.large)   // or .toolbarTitleDisplayMode(.inlineLarge)
```

### Availability menu (leading toolbar)
```swift
ToolbarItem(placement: .navigationBarLeading) {
    Menu {
        Button(action: { toggleAvailability(true) }) {
            Label("Available", systemImage: isAvailable ? "checkmark" : "")
        }
        Button(action: { toggleAvailability(false) }) {
            Label("Unavailable", systemImage: !isAvailable ? "checkmark" : "")
        }
    } label: {
        HStack(spacing: 6) {
            Circle()
                .fill(isAvailable ? Color(.systemGreen) : Color(.systemOrange))
                .frame(width: 8, height: 8)
            Text(isAvailable ? "Available" : "Unavailable")
                .font(.subheadline.weight(.medium))
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .foregroundStyle(isAvailable ? Color(.systemGreen) : Color(.systemOrange))
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }
}
```

### Profile button (trailing toolbar)
```swift
ToolbarItem(placement: .navigationBarTrailing) {
    Button { showProfile = true } label: {
        Image(systemName: "person.crop.circle")
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(.primary)
    }
    .accessibilityLabel("Profile")
}
```

### Toast overlay
```swift
.overlay(alignment: .top) {
    if showToast, let msg = toastMessage {
        HStack(spacing: 12) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "moon.fill")
                .foregroundStyle(isAvailable ? Color(.systemGreen) : Color(.systemOrange))
                .font(.title3)
            Text(msg)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Capsule().fill(.regularMaterial).shadow(color: .black.opacity(0.1), radius: 10, y: 4))
        .transition(.move(edge: .top).combined(with: .opacity))
        .padding(.top, 8)
        .zIndex(1)
    }
}
```

### Greeting card
```swift
private var greetingCard: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(greetingText)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
        Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
}
```

### Active trip card
```swift
private func activeTripCard(_ trip: Trip) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("ACTIVE ASSIGNMENT")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(.systemOrange))
            .kerning(1.2)

        Text(trip.taskId)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.gray.opacity(0.12), in: Capsule())

        Text("\(trip.origin) → \(trip.destination)")
            .font(.headline).foregroundStyle(.primary)

        // Vehicle info (keep existing store lookup logic)
        // ...

        // Scheduled time
        HStack(spacing: 6) {
            Image(systemName: "clock").font(.caption2).foregroundStyle(.secondary)
            Text(trip.scheduledDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                .font(.caption).foregroundStyle(.secondary)
        }

        // View Details button — outline style
        NavigationLink(value: trip.id) {
            Text("View Details")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(.systemOrange))
                .frame(maxWidth: .infinity).frame(height: 40)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(.systemOrange).opacity(0.5), lineWidth: 1.5))
        }
    }
    .padding(16)
    .background {
        // Left orange accent bar
        HStack(spacing: 0) {
            Rectangle().fill(Color(.systemOrange)).frame(width: 4)
            Color.white
        }
    }
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
}
```

### No trip card
```swift
private var noTripAssignedCard: some View {
    VStack(spacing: 14) {
        Image(systemName: "mappin.slash")
            .font(.system(size: 50)).foregroundStyle(.gray.opacity(0.5)).padding(.top, 20)
        Text("No Trip Assigned")
            .font(.headline).foregroundStyle(.secondary)
        Text("Your Fleet Manager hasn't assigned\na delivery task yet.")
            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(2)

        if isAvailable {
            Text("You're waiting for assignment")
                .font(.caption.weight(.medium)).foregroundStyle(Color(.systemGreen))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(.systemGreen).opacity(0.1), in: Capsule())
        } else {
            Text("Set yourself as Available to receive trips")
                .font(.caption.weight(.medium)).foregroundStyle(Color(.systemOrange))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(.systemOrange).opacity(0.1), in: Capsule())
        }
    }
    .padding(.bottom, 20)
    .frame(maxWidth: .infinity)
    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
}
```

### Main body scroll background
```swift
.background(Color(.systemGroupedBackground).ignoresSafeArea())
```

### Keep unchanged
- `greetingText` computed var logic
- `isAvailable` computed var
- `toggleAvailability()` function — all Task/async/await logic
- `currentTrip` and `driverMember` computed vars
- All `store.*` calls
- Sheet presentation for profile modal

---

## FILE 3: `DriverApplicationSubmittedView.swift`

This is the waiting screen shown to new drivers pending approval. Apply:
- Background: `Color(.systemGroupedBackground).ignoresSafeArea()`
- Status card/container: `Color(.secondarySystemGroupedBackground)` rounded corner 16
- Status icon: `.foregroundStyle(.orange)` (pending) or `.foregroundStyle(.green)` (approved)
- Primary text: `.foregroundStyle(.primary)`
- Secondary text: `.foregroundStyle(.secondary)`
- Navigation: this is usually a full-screen view with no nav bar, keep as-is structurally
- Remove all `SierraTheme.Colors.*`, `SierraFont.*`
- Any action buttons: `.orange` for primary
- Sign out button: `.foregroundStyle(.red)` in an appropriate container

---

## MAINTENANCE MODULE

Files in `Sierra/Maintenance/` — apply the same palette migration:
- All backgrounds → `Color(.systemGroupedBackground)` / `Color(.secondarySystemGroupedBackground)`
- Navigation → `.toolbarTitleDisplayMode(.inlineLarge)` + `.toolbarBackground(.hidden)`
- Status colors → system colors
- Remove Sierra tokens
- Keep all data/ViewModel calls
