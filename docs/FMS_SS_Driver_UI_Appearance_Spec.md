# FMS_SS Driver UI Appearance Extraction (Frontend Only)

Source audited: `/Users/kan/Downloads/FMS_SS 3/FMS_SS`

Scope of this document:
- Includes visual design only (layout, spacing, typography, colors, shapes, shadows, motion cues, overlays, component styling).
- Excludes backend, data loading, validation logic, API calls, and state/business logic behavior.

Exact code reference:
- Verbatim frontend reference pack: [README.md](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/README.md)
- Root reference folder: [FMS_SS_Driver_Exact_Code](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code)

## 1) Global Design Language

### 1.1 Color tokens
Defined in `AppTheme.swift`:
- `appOrange` = `Color(red: 0.95, green: 0.55, blue: 0.10)` (primary accent).
- `appAmber` = `Color(red: 1.0, green: 0.75, blue: 0.20)` (accent highlight).
- `appDeepOrange` = `Color(red: 0.90, green: 0.35, blue: 0.08)` (accent depth).
- `appSurface` = `Color(red: 0.97, green: 0.97, blue: 0.96)` (global page background).
- `appCardBg` = `Color.white` (card surfaces).
- `appTextPrimary` = `Color(red: 0.12, green: 0.12, blue: 0.14)` (primary text).
- `appTextSecondary` = `Color(red: 0.45, green: 0.45, blue: 0.48)` (secondary text).
- `appDivider` = `Color(red: 0.92, green: 0.92, blue: 0.93)` (borders/dividers).

Semantic status colors reused across screens:
- Green success: roughly `Color(red: 0.20, green: 0.65, blue: 0.32)`.
- Red alert: roughly `Color(red: 0.90, green: 0.22, blue: 0.18)`.
- Dark panel background family: `Color(red: 0.10-0.17, green: 0.10-0.17, blue: 0.11-0.18)`.

Trip priority palette:
- Urgent: `0.85, 0.18, 0.15`.
- High: `0.95, 0.55, 0.10`.
- Medium: `0.95, 0.75, 0.10`.
- Normal: `0.20, 0.65, 0.32`.

### 1.2 Typography system
No custom font files are present. Typography is system-only.

Primary style:
- `.font(.system(size: X, weight: Y, design: .rounded))` is dominant.

Secondary style:
- `.design: .monospaced` for trip IDs/fleet codes.

Observed font sizes used globally:
- `8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 24, 28, 30, 32, 34, 36, 39, 40`.

Frequent weight usage:
- `.medium`, `.semibold`, `.bold`, `.black`.

Tracking/text-case usage:
- Uppercase labels with `tracking(0.5)` in stats/metadata.
- Home greeting uses tracking `0.5`, driver name uses `1.2`.

### 1.3 Shape language
Corner radius system used repeatedly:
- `10, 14, 16, 18, 20, 22, 24, 26, 30, 32`.

Shape hierarchy:
- `Capsule` for CTAs, chips, badges, segmented action areas.
- `RoundedRectangle` for cards/sheets/panels.
- Special top banner container: `UnevenRoundedRectangle` with only bottom corners rounded.

### 1.4 Spacing system
Common horizontal paddings:
- `20` is primary gutter.
- `16, 18, 22` for internal card layout.
- `28` for modal card edge inset in some overlays.

Common vertical paddings:
- `10-16` for button/control inner spacing.
- `20+` for section separation.

### 1.5 Elevation and borders
Cards:
- subtle shadows with black opacity `0.04-0.08`, radius `10-16`.

Overlays/modals:
- deeper shadows with opacity up to `0.12-0.15`, radius up to `28-30`.

Borders:
- 1 pt strokes mostly in `appDivider.opacity(0.5-0.8)` or semantic tint opacities.

### 1.6 Motion style
Animation signature:
- Spring-based for UI entry/interaction (`response ~0.3-0.7`, `dampingFraction ~0.65-0.9`).
- Linear repeating animations for route dash/road movement.
- Small state pulses (urgent dot, toast pulse, checkmark reveals).

## 2) App Shell and Navigation

## 2.1 Main tab bar
From `MainTabBar.swift`:
- Native `TabView` with 4 tabs: Home, Trips, Alerts, Profile.
- Icons: `house.fill`, `map.fill`, `bell.fill`, `person.fill`.
- Accent/tint: `.appOrange`.
- Tab item typography:
  - selected: system size `11`, `bold`.
  - normal: system size `11`, `medium`.
- Background: system background.

## 2.2 Global background strategy
- Light mode surfaces for Home/Trips/TripOverview/Inspection (`appSurface`).
- Dedicated dark mode composition only for Active Navigation screen.

## 3) Home Screen Visual Spec

Source: `ContentView.swift` (`HomeView` + sections).

Layout:
- ScrollView on `appSurface`.
- Header block fixed height `230`.
- Main content stack spacing `16` under header.
- `CurrentRouteBanner` intentionally overlaps header (`.padding(.top, -30)`).

Header section:
- 3-layer gradient composition:
  - base linear gradient (`appAmber -> appOrange -> appDeepOrange.opacity(0.85)`).
  - top-left radial white glow (`opacity 0.25`).
  - bottom-right radial deep-orange glow (`opacity 0.4`).
- Bottom corners rounded to `32`, top corners square.
- Availability control at top-right with green/gray status dot and scaled toggle (`0.85`).
- Greeting text: size `16 medium rounded`, white `0.9`.
- Name text: size `28 bold rounded`, white, tracking `1.2`.

Availability toast:
- Capsule with green or muted dark fill.
- Padding `horizontal 18`, `vertical 14`, overall top offset `58`.
- Iconography + pulse dot animation.

Current route banner:
- Frosted card (`.ultraThinMaterial`), radius `20`.
- Internal paddings: `horizontal 18`, `vertical 14`.
- Leading dark circular icon container `44x44`.
- White border stroke (`opacity 0.7`), shadow radius `12`.

Upcoming rides card:
- Outer card radius `24`.
- Top area:
  - left text block (`14` + `22` sizes).
  - right illustrative tile `80x70`, radius `16`.
- CTA button:
  - full width capsule, vertical padding `14`.
  - dark fill (`appTextPrimary`), white text size `15 bold`.

Recent trip list section:
- Heading size `20 bold rounded`.
- "View All" text button size `14 semibold` in orange.
- Reuses `AllTripCard` visual style from Trips screen.

## 4) Trips Screen Visual Spec

Source: `Tripsview.swift`.

Top/header:
- Large nav title "All Trips".
- Filter icon in a `36x36` circular hit area, orange tint.
- StatsBar directly below with outer radius `18`.

StatsBar:
- Three equal stat cells (Total, Urgent, Accepted).
- Stat number size `22 bold rounded`.
- Label size `11 semibold uppercase` with tracking `0.5`.
- Vertical card padding `14`, horizontal `8`.

Filter banners:
- Active/Completed banners use radius `14`, padding `16x11`.
- Left icon size around `13`, text `14 semibold rounded`.
- "Clear" micro action text `13 bold`.

Trip cards (`AllTripCard`):
- Outer card radius `22`, padding `18`.
- Shadow tinted by trip priority color (`opacity 0.10`).
- Border stroke:
  - accepted pulse: green-ish stronger stroke.
  - default: priority-tinted stroke (`opacity ~0.22`).
- Main text:
  - route cities size `18 bold rounded`.
  - trip code size `13 bold monospaced`.
  - fleet code size `12 bold monospaced` in orange capsule.
  - date row size `13 medium rounded`.
- Route arrow:
  - dashed 30 pt line + tiny triangle icon.

Card action row:
- Dual capsule buttons with vertical padding `12`.
- Primary button changes style by state:
  - Navigate state: filled red (`0.90, 0.22, 0.18`) with white text.
  - Default state: orange-tinted background and orange text.
- Secondary accept button:
  - dark filled for default accept.
  - green-tinted muted style after accepted/completed.

Priority and completed badges:
- Capsule with 12x6 padding.
- Text size `12 bold rounded`.
- Urgent includes pulsing dot.

Trip detail overlay:
- Full-screen dim (`black 0.45`) with centered card.
- Card has route preview placeholder block height `150`, radius `16`.
- Date/time row split left-right.
- Distance pill with dashed capsule border.

Slide to start control:
- Height default `60` (or `44` in specific compact usage).
- Track capsule with border.
- Knob gradient (`appAmber -> appOrange -> appDeepOrange`).
- Completion threshold around `82%` drag distance.

Overlays:
- Accept-required modal: frosted rounded rectangle radius `32`.
- Waiting-vehicle modal: frosted card radius `24`, max width `330`.
- Accept success overlay: frosted card radius `32` with animated green circles/check.

## 5) Trip Overview Screen Visual Spec

Source: `TripOverviewView.swift`.

Structure:
- Scroll content with `heroMapSection`, `routePlanCard`, `vehicleCard`.
- Floating bottom navigate CTA over content.

Hero map section:
- Height `320`, radius `30`.
- Background gradient (soft green/blue-gray).
- Overlaid map grid with 44 pt spacing lines.
- Curved dashed route stroke (`lineWidth 4`, dash `[8,6]`, blue `0.35` opacity).
- Floating top chip:
  - white capsule (`opacity 0.96`), icon size `9`, text size `12`.
- Floating summary card:
  - radius `22`, white `0.97` fill.
  - title size `18`, stop badge size `12`.
  - trip code row size `13`.
  - 3 equal mini stats with icon circles `22x22`.

Route plan card:
- Card radius `26`, padding `18`.
- Timeline column uses two `44x44` icon circles connected by 3 pt gradient line.
- Route node badges size `10`, city size `14`, subtitle `12`, meta `11`.

Vehicle card:
- Radius `20`, padding `16x14`.
- Fleet code in orange capsule.
- Vehicle type text size `14 semibold rounded`.

Bottom navigate button:
- Full-width capsule, horizontal inset `20`, bottom `18`.
- Red fill (`0.90, 0.22, 0.18`), label size `14 bold`.

## 6) Active Navigation Screen Visual Spec

Source: `ActiveNavigationView.swift`.

Overall tone:
- Full black immersive screen with hidden status/navigation bar.
- Moving-road illusion:
  - dark vertical gradient.
  - center strip + repeating orange lane dashes.

Top instruction card:
- Radius `24`, dark near-black fill, subtle white stroke.
- Left icon tile `52x52`, tint depends on alert state.
- Text hierarchy:
  - distance line size `12`.
  - instruction line size `21 bold`.
  - road line size `13`.

Speed ring:
- Outer circle `132`, inner `116`.
- Speed text size `39 bold`, unit `12`.

Bottom control block:
- Main panel radius `26`.
- Destination title size `20 bold` uppercased.
- Dismiss button in red circular container `36x36`.
- Two stat cards radius `18`, title size `10 uppercase`, value size `19`.
- Progress bar height `8` with green-orange gradient fill.
- Context alert strip radius `14`.

Quick action buttons:
- Radius `14`, vertical padding `14`.
- Three actions: Mute, Report Issue, End Trip.

Modal styling (all dark themed):
- End trip, delivery proof, and issue report sheets:
  - dark cards radius `22`.
  - white stroke opacity around `0.05-0.08`.
  - bottom anchored with horizontal inset `20` and bottom offset around `96-104`.
- Upload rows in sheets:
  - row radius `14`, icon box `44x44`, check/plus state icon.

Top toast:
- Orange capsule at top (issue sent), size `14 bold` text.

## 7) Pre-trip/Post-trip Inspection Screen Visual Spec

Source: `Pretripinspectionview.swift`.

Top chrome:
- Custom nav row with circular back/close button `38x38`.
- Title centered size `18 bold rounded`.
- Step progress bar below, horizontal inset `40`.

Progress bar:
- 3 step dots (`16x16`) connected by 3 pt bars.
- Active/completed dots in orange, future in divider gray.

Checklist step:
- Large rounded card radius `20`.
- Row layout:
  - icon column width `28`, icon size `18`.
  - item text size `15 semibold`.
  - trailing switch toggle.
- Expanded issue panel:
  - status chips (Warn/Fail) as capsules.
  - details `TextEditor` with radius `14` and min height `80`.

Uploads step:
- Uses `PhotoUploadCard` components.
- Card radius `22`, padding `18`.
- Capture area:
  - height `130`, radius `16`, dashed border.
  - empty state: camera icon `28`, label size `12`.
  - captured state: check icon `32`, green accents.

Fail-flow uploads:
- Warning strip with triangle icon size `13`.
- Two proof upload cards, same visual system.

Signature step:
- Card radius `22`, padding `18`.
- Canvas area:
  - height `180`, dashed border radius `16`.
  - draw stroke width `2.5`.
- Placeholder "Sign here" centered when empty.
- "Clear" micro action in orange.

Bottom actions:
- Primary `ActionButton`:
  - capsule, vertical padding `17`.
  - label size `16 bold`.
  - shadow when enabled.
- Secondary action:
  - capsule tint fill (`10%`) + border (`35%`), size `15`.

Maintenance request modal:
- Dark bottom sheet, radius `22`.
- Text editor height `110`, radius `14`.
- Upload row and dual actions mirror dark modal style from navigation screen.

Completion overlays:
- Inspection complete:
  - white card radius `32`.
  - green center circle `80x80` with concentric animated rings.
- Vehicle change requested:
  - frosted card radius `32`.
  - orange center circle `80x80`.

## 8) Reusable Common Components

Source: `Components/StateComponents.swift`.

Fallback error banner:
- Red rounded rectangle radius `14`.
- Left warning icon size `13`, message size `13 semibold rounded`.
- Dismiss icon size `16`.
- Padding `14x11`.

Empty state card:
- Radius `18`, white card with subtle shadow.
- Icon size `30`, title `18`, subtitle `13`.
- CTA is orange-tinted capsule with thin border.
- Card vertical padding `24`.

## 9) Practical Port Notes for Sierra (Appearance-only mapping)

- Keep the same visual token stack: orange-driven accent on light surfaces for normal screens, dark immersive treatment only for active navigation.
- Preserve rounded-system hierarchy:
  - small controls `10-16`,
  - cards `18-26`,
  - hero/overlay `30-32`.
- Preserve typographic hierarchy exactly:
  - major titles `20-22+`,
  - route labels `18`,
  - metadata `11-14`,
  - monospaced trip/fleet IDs.
- Keep full-width capsule CTAs as a signature pattern.
- Keep modal language consistent:
  - dimmed backdrop + bottom-anchored rounded dark card for operational actions,
  - center frosted/white celebratory overlays for success states.
- Keep subtle motion, not flashy:
  - spring for transitions,
  - linear loops for route/road indicators,
  - one localized pulse for urgency/success.
