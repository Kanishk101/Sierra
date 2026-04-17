# Sierra Fleet Management System

Sierra is a SwiftUI-based Fleet Management app for three operational roles:

- Fleet Manager
- Driver
- Maintenance Personnel

It supports trip planning and execution, inspections, maintenance workflows, alerts, and role-based dashboards for daily fleet operations.

## Core Features

- Role-based auth and dashboard routing
- Fleet manager trip assignment and live operations views
- Driver trip lifecycle:
  - trip acceptance
  - pre-trip inspection
  - navigation flow
  - proof of delivery
  - post-trip inspection
- Maintenance workflow:
  - task approval and assignment
  - work orders and phases
  - spare parts requests and inventory visibility
- Alerts and notifications:
  - emergency alerts
  - route deviations
  - activity feed
- Supabase-backed services for auth, data, and edge functions

## Tech Stack

- iOS app: Swift, SwiftUI
- Backend: Supabase (Auth, PostgREST, Realtime, Edge Functions)
- Mapping/navigation: Mapbox packages
- Build system: Xcode + Swift Package Manager

## Repository Layout

- Sierra: iOS app source
- SierraTests: unit tests
- supabase/migrations: SQL schema and seed migrations
- supabase/functions: edge functions
- scripts/bootstrap.sh: local machine bootstrap script
- SETUP.md: setup quick guide

## Prerequisites

- macOS with Xcode installed
- Command line tools for Xcode
- Mapbox downloads token (secret token starting with sk.)

## Quick Start

1. Bootstrap local machine and resolve dependencies

    ./scripts/bootstrap.sh

2. Open the project in Xcode

    Sierra.xcodeproj

3. Build the Sierra scheme

## Run From Terminal (Simulator)

Build for iPhone 17 Pro simulator:

    xcodebuild -project Sierra.xcodeproj -scheme Sierra -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

Install and launch:

    UDID=$(xcrun simctl list devices | awk -F '[()]' '/iPhone 17 Pro/ && /Booted/ {print $2; exit}')
    if [ -z "$UDID" ]; then
      UDID=$(xcrun simctl list devices | awk -F '[()]' '/iPhone 17 Pro/ && !/unavailable/ {print $2; exit}')
      xcrun simctl boot "$UDID"
    fi
    APP="$HOME/Library/Developer/Xcode/DerivedData/Sierra-feytbtdkhxxucucuqykltoixjcus/Build/Products/Debug-iphonesimulator/Sierra.app"
    xcrun simctl install "$UDID" "$APP"
    xcrun simctl launch "$UDID" com.kanishk.Sierra

## Authentication Modes

### 1. Supabase Seeded Accounts

Current role-based seeded credentials in migrations:

| Role | Email | Password |
|---|---|---|
| Fleet Manager | fleetmanager.test@sierra.fms | test1234 |
| Driver | driver.test@sierra.fms | test1234 |
| Maintenance | maintenance.test@sierra.fms | test1234 |

Notes:

- Additional legacy seeded users still exist for broader test coverage
- If Supabase host is unreachable, these credentials cannot complete remote auth

### 2. Expo Local Bypass Mode (Currently Active)

- Sign-in succeeds regardless of input values
- User is routed through local bypass flow
- Local bypass state is persisted
- Data store hydrates rich local demo datasets so screens are populated without backend dependency

## Demo Data Coverage

When local bypass mode is active, the app auto-loads:

- Staff and profiles
- Vehicles with live-like coordinates
- Trips in multiple statuses:
  - PendingAcceptance
  - Scheduled
  - Active
  - Completed
- Inspections and proof of delivery
- Fuel logs
- Maintenance tasks, work orders, work order phases
- Spare parts requests and inventory parts
- Geofences, activity logs, notifications, route deviation events

## Supabase Notes

- Supabase URL and anon key are configured in app services
- Migrations define schema and seed users
- For fresh backend setup, run project migrations in order using your Supabase workflow

## Testing

Run tests from Xcode, or via terminal:

    xcodebuild test -project Sierra.xcodeproj -scheme Sierra -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

## Troubleshooting

### Package resolution fails

Run:

    xcodebuild -resolvePackageDependencies -project Sierra.xcodeproj -scheme Sierra

Also verify your home netrc contains mapbox machine entries and correct token.

### Build succeeds but login fails remotely

Likely causes:

- Supabase hostname/DNS issue
- session/token mismatch
- network connectivity failure

Use expo local bypass mode for demo continuity.

### Empty screens after login

If using bypass mode, ensure local demo hydrator path is active in data loading services.

## Security Notes

- Do not commit secret tokens
- Mapbox download token must stay machine-local
- Test credentials in seeds are for development/demo only
- Rotate or remove demo credentials before production release

