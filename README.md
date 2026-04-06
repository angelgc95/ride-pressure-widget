# Ride Pressure Widget

![Ride Pressure cover](docs/assets/cover.svg)

City-level mobility pressure signal for taxis and ride-hailing demand.

Public demo link is intentionally omitted until a stable deployment is published.

## Problem

Route quote tools answer the price of one trip. They do not tell a rider, operator, or city observer whether the local ride market is broadly favorable, normal, or under pressure right now.

## Solution

Ride Pressure Widget turns live weather, geolocation, route-friction observation, and transparent provider support states into a city-level pressure view. It is designed as a widget-like product surface, not a fare estimator.

## Key Features

- Manual city search plus automatic location detection
- City-level market classification: favorable, normal, or rough
- Weather, traffic, and demand breakdowns behind the score
- Provider support states that stay neutral when live pricing is not trustworthy
- Persisted observed snapshots in SQLite for recent city baselines
- Mobile-first `/widget` route and installable web-app metadata
- Native SwiftUI iPhone app and WidgetKit companion project

## Data Sources

- Open-Meteo for current and forecast weather
- Nominatim for reverse geocoding
- ipwho.is for IP-based city fallback
- Public Uber route probes for route-friction observation
- SQLite via `better-sqlite3` for local snapshot persistence

## Data Integrity

### What is real

- City search and reverse geocoding
- Current and forecast weather
- Real observed snapshots written to SQLite
- Uber public-web route timing signals when probes succeed

### What is inferred

- Hourly and daily outlook curves
- Demand pressure layering when direct provider pricing is limited

If a city falls back to inferred signals, the UI says so instead of pretending direct provider coverage exists.

## Stack

- Next.js 16, React 19, TypeScript
- Tailwind CSS 4
- Recharts
- SQLite via `better-sqlite3`

## Architecture

- `src/app/api/` exposes search, reverse geocoding, and market payload endpoints.
- `src/lib/server/sources/` handles weather and geocoding.
- `src/lib/server/providers/` contains provider adapters.
- `src/lib/server/market.ts` computes pressure, freshness, and chart outputs.
- `src/lib/server/snapshots.ts` stores and reads local observed baselines.
- `src/components/market-widget.tsx` and `src/components/pressure-chart.tsx` drive the main UI.

## Run Locally

```sh
npm install
npm run dev
```

Open `http://localhost:3000` for the full app or `http://localhost:3000/widget` for the compact widget view.

The app creates a local SQLite file at `data/ride-pressure.sqlite`.

## Native iPhone App

- `ios/RidePressureIOS` contains the SwiftUI app and WidgetKit extension.
- The iPhone project uses the same real-data posture as the web app.
- Generate the Xcode project with `xcodegen generate` inside `ios/RidePressureIOS`.
- Local build verification on this machine still requires the Xcode license to be accepted.

## Current Status

- Build passes for the web application
- Provider support is intentionally conservative and explicit
- Strongest coverage currently comes from weather plus Uber route-friction observation

## Limitations

- This build does not claim reliable live price access for Bolt, Cabify, or FREE NOW.
- Some cities will fall back to weather plus inferred demand until more provider adapters are added.
- The charts are outlooks built from current signals, not fabricated historical archives.
