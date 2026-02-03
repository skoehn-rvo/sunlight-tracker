# Sunlight Tracker

A macOS menu bar app that shows daylight statistics and milestones as days get longer from winter toward spring.

## Features

- **Menu bar icon** — Sun icon in the top bar; click to open the panel
- **Today’s daylight** — Total day length and local sunrise/sunset
- **Since winter solstice** — How many minutes of daylight you’ve gained
- **Milestones** — Badges for 1 min, 5 min, 15 min, 30 min, 1 hr, 1.5 hr, 2 hr more daylight
- **Spring equinox** — Countdown (or “passed”) for the March equinox

Sunrise, sunset, and day length come from the free [Sunrise-Sunset API](https://sunrise-sunset.org/api) (no API key). Your Mac’s time zone is used for display. Location is fixed in code (`SunlightService.defaultCoordinate`); you can add a location picker later.

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

The app runs as a menu bar–only app (no Dock icon). The first time you run from Xcode, the sun icon appears in the menu bar; click it to see the stats.

## Project structure

```
SunlightTracker/
├── SunlightTrackerApp.swift   # App entry, AppDelegate
├── MenuBarController.swift   # Status item + popover
├── StatsView.swift           # Popover UI (SwiftUI)
├── SunriseSunsetAPI.swift    # Fetches from api.sunrise-sunset.org
├── SunlightService.swift     # Loads today + solstice, holds state
├── Info.plist                # LSUIElement (menu bar only)
└── Assets.xcassets           # App icon, accent color
```

## Changing location

Edit `SunlightService.defaultCoordinate` in `SunlightService.swift`. Coordinates are in decimal degrees (e.g. 44.94, -92.67 for your current default).

## License

Use and modify as you like.
