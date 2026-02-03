# Sunlight Tracker

A macOS menu bar app that shows daylight statistics and key seasonal milestones as days get longer (or shorter) through the year.

## Features

- **Menu bar icon** — Sun icon in the top bar; click to open the panel
- **Today’s daylight** — Total day length and local sunrise/sunset
- **Change from yesterday** — How many minutes longer or shorter than yesterday
- **Since solstice** — Change in day length since the most recent winter or summer solstice, plus sunrise/sunset shift vs that solstice
- **Next key day** — Countdown to Spring Equinox, Summer Solstice, Fall Equinox, or Winter Solstice (or “today/tomorrow” when relevant)
- **Shortest → longest day** — Percent of the way from winter solstice to summer solstice
- **Civil twilight** — Begin/end times when available from the API
- **Location search** — Pick a US city from the popover; location is saved and reverse‑geocoded for a friendly display name

Sunrise, sunset, and day length come from the free [Sunrise-Sunset API](https://sunrise-sunset.org/api) (no API key). Your Mac’s time zone is used for display.

## Requirements

- macOS 13.0 or later
- Xcode 15+ (to build)

## Build and run

1. Open the project in Xcode:
   ```bash
   open SunlightTracker.xcodeproj
   ```
2. Choose the **Sunlight Tracker** scheme.
3. Press **Run** (⌘R).

The app runs as a menu bar–only app (no Dock icon). The first time you run from Xcode, the sun icon appears in the menu bar; click it to see the stats. Click your location name to search for and set a different city.

## Project structure

```
SunlightTracker/
├── SunlightTrackerApp.swift   # App entry, menu bar setup
├── MenuBarController.swift   # Status item + popover
├── StatsView.swift           # Popover UI (SwiftUI)
├── LocationSearchView.swift  # City search (MapKit completer)
├── SunriseSunsetAPI.swift    # Fetches from api.sunrise-sunset.org
├── SunlightService.swift     # Location, API state, solstice/equinox logic
├── Info.plist                # LSUIElement (menu bar only)
└── Assets.xcassets           # App icon, accent color
```

## Changing location

Use the in-app location picker: open the popover and tap the location name (e.g. “Current location” or “City, State”). Search for a US city, pick a result, and the app saves the coordinates and shows the new display name.

To change the **default** location (used when none is saved), edit `SunlightService.defaultCoordinate` in `SunlightService.swift`. Coordinates are in decimal degrees (e.g. 44.94, -92.67).

## License

Use and modify as you like.
