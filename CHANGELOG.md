# Bokses — Changelog

## 0.1.2 — 2026-06-19

### Added
- App icon updated to the Bokses icon on both iOS and Android
- Android splash screen now shows the Bokses icon centered on a dark background
- BoksTalk — voice-to-item mode on box detail screen. Tap the BoksTalk FAB to open a listening session; say an item name and after a configurable silence window it automatically adds the item and loops back to listening. Cancel manually when done.
- BoksTalk settings — silence timeout slider (0.5s–5.0s, default 1.5s) and a Read Back toggle that speaks the heard text aloud before adding

### Changed
- App bar logo removed; "Bokses" title now renders as a gradient from the primary to the accent theme color
- Box cards now gradient across the full sorted list — first card is the primary color, last is the accent, cards in between blend proportionally; reordering the list updates all colors
- New Box button redesigned as a gradient pill matching the title gradient
- Export filename now uses a compact timestamp (`bokses_export_YYYYMMDD_HHMMSS.json`) with no spaces
- Export now opens a native save-to-filesystem dialog (iOS Files app, Android document picker, macOS/Windows save dialog) instead of defaulting to a share sheet; share sheet is used only as a fallback

---

## 0.1.1 — 2026-06-18

### Added
- Box sorting — sort grid by date (oldest/newest) or name (A–Z / Z–A) via the pill button in the summary bar
- Fragile label — toggle in the new/edit box sheet marks a box with a yellow caution badge visible on the card and in search results
- Web splash screen — shows the Bokses icon (dark or light based on OS preference) while the app loads instead of a blank page

### Changed
- Local storage — data now saves directly in the browser (IndexedDB via SharedPreferences); no backend or Docker required
- Backend, Docker Compose, nginx config, and deploy script removed

### Fixed
- Android Gradle build output redirected to `/private/tmp/bokses-gradle` — fixes `Unable to delete file` build failure when the project lives on an ExFAT volume

---

## 0.1.0 — 2026-06-18

First versioned release milestone.

### Added
- Android and iOS platform support
  - `INTERNET` permission for Android network calls
  - `NSAppTransportSecurity` for iOS HTTP connections to local/remote servers
  - Configurable server URL in Settings (mobile only) — defaults to `http://localhost:8743`
  - Server URL persisted to SharedPreferences and applied at startup
- Comprehensive widget + unit test suite (89 tests)
  - Model round-trip tests (Box, Item)
  - FakeDatabaseService CRUD, search, and cascade-delete tests
  - ImportExportService export payload and import round-trip tests
  - HomeScreen: empty state, grid, add/edit/delete box, search
  - BoxDetailScreen: empty state, item list, add/edit/delete item, navigation

### Changed
- Version scheme reset from `0.0.x` internal builds to `0.1.0`
- Removed top-level `mobilenet-v2-tflite-1-0-224-metadata-v1.tar` (unused download artifact)
- Removed `assets/ml/mobilenet_v2.tflite` (VisionService is currently a stub)
- Removed stale top-level `bokses-icon.svg` and `bokses-icon.iconproj` (moved to `assets/icons/`)
- `._*` macOS resource fork files excluded from git

### Internal
- `DatabaseService.serverUrl` static field replaces hardcoded `Uri.base` on non-web platforms
- `SettingsService.getServerUrl` / `setServerUrl` added
- Server URL loaded at app startup in `main()`

---

## 0.0.23 — 2026-06-11

### Added
- Comprehensive widget + unit test suite (89 tests)
  - Model round-trip tests (Box, Item)
  - FakeDatabaseService CRUD, search, and cascade-delete tests
  - ImportExportService export payload and import round-trip tests
  - HomeScreen: empty state, grid, add/edit/delete box, search
  - BoxDetailScreen: empty state, item list, add/edit/delete item, navigation

---

## 0.0.22 — 2026-06-11

### Fixed
- Loading fix — API errors no longer hang the spinner

### Changed
- Redesigned app bar: gradient B logo, pill action buttons with divider

---

## 0.0.21 — 2026-06-11

### Added
- Version footer with changelog tooltip and full history page

### Fixed
- Web export now downloads a file directly
- Fixed export crash when server returns unexpected response

### Changed
- Title changed to capital-B Bokses, subtitle removed

---

## 0.0.20 — 2026-06-11

Initial versioned release.

### Added
- Server-side SQLite storage via FastAPI backend
- Docker Compose deployment with nginx reverse proxy
- Dark icon set as web favicon
- One-command deploy script
