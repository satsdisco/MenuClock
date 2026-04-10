# MenuClock

A native macOS menu bar app that shows your local time alongside world clocks, upcoming calendar events, and (optionally) current weather.

Built in Swift + SwiftUI. No Electron, no web views, no third-party dependencies, no telemetry, no backend.

## Features

- **World clocks** with day labels (Today / Tomorrow / Yesterday)
- **Search any city** — 68,000+ cities worldwide via the bundled GeoNames dataset, with state/province disambiguation (Meridian, Idaho vs Meridian, Mississippi)
- **Local time auto-shown** at the top of the dropdown, derived from your system time zone
- **Upcoming calendar events** from any subset of your calendars (iCloud, Google, Exchange, etc.) with colored dot per calendar; click to open Calendar.app at the event
- **Weather** (opt-in) — current temperature + SF Symbol weather icon next to each clock, fetched from [Open-Meteo](https://open-meteo.com) (free, no API key, no tracking)
- **Customizable menu bar format** — local time only, or local + secondary clock with city codes; choose your separator (`•`, `·`, `|`, `—`, `/`, or just spacing); toggle the local label
- **12 / 24 hour override** independent of system locale
- **Launch at login** via `SMAppService`
- **Native dark mode**, SF Symbols throughout, follows system appearance
- **Sandboxed**, hardened runtime, ad-hoc signed for local builds

## Architecture

MVVM with cleanly separated layers:

```
MenuClock/
├── Models/         # WorldClock, AppSettings (enums)
├── Managers/       # SettingsManager, ClockTicker, CalendarManager,
│                   # CityDatabase, WeatherManager, LaunchAtLoginManager,
│                   # TimeFormatting
├── ViewModels/     # MenuBarViewModel
├── Views/          # DropdownView, WorldClockRow, EventRow,
│                   # SettingsView, TimeZonePickerView, MenuBarTitleView
├── Resources/      # Info.plist, cities.tsv (built artifact)
└── Assets.xcassets # AppIcon
```

## Building

### Quick build (no Xcode required)

`build.sh` compiles all sources directly with `swiftc`, assembles the `.app` bundle, generates the icon if missing, and ad-hoc codesigns it.

```bash
./build.sh        # build only
./build.sh run    # build, kill any running instance, launch
```

The first build needs the city database — fetch it once:

```bash
./build/fetch_cities.sh
```

This downloads GeoNames `cities5000.zip` + `admin1CodesASCII.txt`, joins them, and writes `MenuClock/Resources/cities.tsv` (~5 MB, 68k cities). After that the build is fully offline.

### With Xcode

Open `MenuClock.xcodeproj` and Cmd+R. The hand-rolled pbxproj wires everything; on first open Xcode will offer to create a scheme — accept.

## Requirements

- macOS 13 Ventura or later
- Swift 5.0+
- For the manual build: Apple Command Line Tools (no full Xcode needed)
- Calendar permission (prompted on first launch)
- Network only if Weather is enabled

## Privacy

MenuClock makes **zero** network calls in its default configuration. No telemetry, no analytics, no crash reporting.

If you opt in to **Weather**, the app makes one HTTPS request per ~15 minutes to `api.open-meteo.com` per configured world clock, sending only the city's coordinates. Open-Meteo does not require an account or API key and does not track requests.

Calendar data is read locally via EventKit and never leaves your machine.

## Acknowledgments

- City data: [GeoNames](https://www.geonames.org) cities5000 dataset, CC BY 4.0
- Weather data: [Open-Meteo](https://open-meteo.com), CC BY 4.0
- SF Symbols by Apple

## License

MIT — see [LICENSE](LICENSE).
