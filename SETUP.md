# Sierra Setup

Use this once after cloning to configure Mapbox package downloads and resolve dependencies.

## 1. Prerequisites

- Xcode installed
- Access to the team `MAPBOX_DOWNLOADS_TOKEN` (starts with `sk.`)

## 2. Bootstrap (one command)

From repo root:

```bash
./scripts/bootstrap.sh
```

The script will:

- Prompt for `MAPBOX_DOWNLOADS_TOKEN`
- Write Mapbox credentials to `~/.netrc` (permissions `600`)
- Resolve Swift Package Manager dependencies for the `Sierra` scheme

## 3. Build

Open:

- `Sierra.xcodeproj`

Build scheme:

- `Sierra`

## 4. Notes

- `MBXAccessToken` (`pk...`, public token) is read from:
  - `Sierra/Info.plist`
- `MAPBOX_DOWNLOADS_TOKEN` (`sk...`, secret) is machine-local and must **not** be committed.
- Dependency versions are pinned in:
  - `Sierra.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

## 5. If package resolution fails

Run:

```bash
xcodebuild -resolvePackageDependencies -project Sierra.xcodeproj -scheme Sierra
```

Then verify `~/.netrc` contains both:

- `machine api.mapbox.com`
- `machine downloads.mapbox.com`
