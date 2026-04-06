# Ride Pressure iOS

Native SwiftUI iPhone app for the Ride Pressure project.

## What it does

- Detects the current city with Core Location and reverse geocoding
- Lets the user switch cities manually with real Open-Meteo geocoding
- Builds the same city-level pressure index from real weather plus public Uber route probes when available
- Keeps Bolt, Cabify, and FREE NOW explicitly unsupported until a real verified adapter exists
- Persists real observed snapshots locally to build route baselines and freshness handling
- Ships a native home-screen widget for iPhone with medium and large families only
- Lets the widget use either the app's current city or its own configured city string

## Project structure

- `project.yml`: XcodeGen spec for the iOS app target
- `RidePressureApp/Services`: network, location, provider adapters, snapshot archive, market engine
- `RidePressureApp/Views`: SwiftUI screens and chart-first components
- `RidePressureWidget`: WidgetKit extension for the home-screen widget
- `Shared`: app/widget shared cache and city state helpers

## Generate the Xcode project

```bash
cd /Users/angel/Documents/Playground/ride-pressure-widget/ios/RidePressureIOS
xcodegen generate
open RidePressureIOS.xcodeproj
```

If `xcodebuild` is still pointing at Command Line Tools, build with:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project RidePressureIOS.xcodeproj -scheme RidePressure -destination 'generic/platform=iOS Simulator' build
```

## Data honesty

- Provider green, orange, and red are reserved for real observed provider prices relative to recent local baseline.
- Unsupported or route-only providers stay neutral.
- The city pressure index remains useful even when provider price access is limited because it still uses real weather and direct Uber route friction where available.

## Home-screen widget notes

- The widget is home-screen only. There is no lock-screen widget in this project.
- The widget can mirror the app's current city through shared app state when App Groups are available.
- The widget can also fetch independently from a city configured in widget settings, which keeps it useful even during local simulator runs where `Sign to Run Locally` strips App Group entitlements.
