# Bokses — Changelog

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
