# Bokses — Changelog

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

## Earlier builds (0.0.20 – 0.0.23)

See in-app Version History screen (`v` footer on the home screen) for the full pre-release changelog.
