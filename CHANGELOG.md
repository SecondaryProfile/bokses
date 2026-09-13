# Bokses — Changelog

## 0.13 — 2026-09-13

- More tests, with a coverage check in CI
- Fixed a few AI provider bugs the new tests caught

---

## 0.12 — 2026-09-13

### Added
- **AI Provider** replaces the Model Hub — connect your own Gemini, Claude, or
  ChatGPT API key for image recognition instead of downloading on-device models.
  Requests go straight from the browser to the chosen provider over HTTPS; no
  Bokses server is involved.
- Debug log screen for troubleshooting

### Changed
- **Bokses is now a web-only app.** The Android, iOS, macOS, Windows and Linux
  targets are gone; the only build output is `flutter build web`, intended to be
  served from a container.
- API keys are now encrypted at rest in browser storage rather than the iOS
  Keychain / Android Keystore — private to the browser profile, not the device
- Export downloads a JSON file from the browser instead of writing to the file
  system or invoking a share sheet; web-sourced photo URLs now survive an
  export/import round trip
- Debug log is an in-memory rolling buffer for the session, downloadable as a
  `.txt`, instead of a file on disk

### Removed
- On-device ONNX model hub, model downloads, and the Small / Medium / Large / XL
  tiers
- SysML v2 architecture model (`bokses_architecture.sysml`), the generated
  `requirements.csv` / `requirements.xls`, and `tools/extract_requirements.py`
- Native-only dependencies: `path_provider`, `permission_handler`,
  `share_plus`, `flutter_launcher_icons`, plus the unused `path` and
  `cupertino_icons`. Camera permission is now the browser's own
  `getUserMedia` prompt.

---

## 0.10 — 2026-06-23

### Added
- **AI model hub** — four downloadable tiers, selectable in Settings:
  - Small: MobileNet V3 Large (~22 MB)
  - Medium: EfficientNet-Lite4 (~49 MB)
  - Large: ViT-B/16 (ONNX, ~335 MB)
  - XL: OpenCLIP ViT-L/14 (ONNX, ~900 MB)
- ONNX Runtime support alongside TFLite — Large and XL models run via on-device ONNX inference
- **Internet image search** — "Find online" button in add/edit item dialogs searches DuckDuckGo Images and shows a thumbnail grid; tap to set as the item photo (no API key, no account required)
- **Bulk photo fill** — `image_search` button in a box's app bar finds web photos for every item that has none, with a confirmation dialog before proceeding; progress shown in the app bar
- Globe badge on web-sourced photos to distinguish them from camera captures

### Changed
- Refreshed app icon across all Android screen densities (smaller, cleaner artwork)
- Bokses wordmark on the home screen now has a dark outline so it reads on any background or theme colour
- Box card border thickness unified — grid cards now match list tiles (both 7 px)
- Edit item dialog redesigned: full-width photo area (160 px tall), Camera / Find online / Remove action button row below the photo, labels in their own bordered section below that
- View mode toggle re-enable time reduced from 2.5 s to 1 s

---

## 0.9 — 2026-06-22

### Added
- Swipe right on items to reveal a yellow **Move** button — opens a centered popup to move the item to another box
- AutoBoks front/rear camera toggle button overlaid on the live preview

### Changed
- Move to Box redesigned as a centered popup dialog instead of a bottom sheet
- Item and box swipe menus now follow iOS single-open behaviour — opening one automatically closes any other
- AutoBoks: snap sound and photo capture fire simultaneously via `Future.wait`; removes the perceptible delay between the audio cue and the shutter
- Photo and label picker shown side-by-side in the add and edit item dialogs
- Search bar gets a solid surface background when active, ensuring text is legible over any custom photo background
- Swipe action corner pockets show the correct color — blue on the edit/delete side, yellow on the move side
- Item card borders match the gradient color of their parent box

### Fixed
- Swipe corner pockets no longer show white when an item is revealed

---

## 0.8 — 2026-06-19

### Added
- List view for the home screen — toggle between grid and list in the summary bar
- iOS-style swipe actions on box list rows and item rows: short swipe reveals Edit / Delete; full swipe deletes with an undo toast
- Item labels — Fragile, Battery, Liquid — added via a Labels button in the add/edit item sheet; shown on box cards and list tiles
- Instant Load setting — skips fade-in animations so content appears immediately
- Animated splash screen
- Import progress dialog
- Box descriptions in list view and as a subtitle under the app bar
- **AutoBoks** — hands-free voice-to-item mode with automatic photo capture
- AutoBoks live camera preview in the sheet
- Camera toggle in AutoBoks settings
- **Background** setting — Default, Gradient, Photo (with blur slider), or Solid
- **Move to Box** — three-dot menu on any item

### Changed
- Settings screen redesigned with iOS-style grouped cards
- Box deletion now uses instant-delete + undo-toast; confirmation dialog removed

### Fixed
- Undo toast no longer stacks when items are deleted in quick succession
- Import progress dialog race condition fixed
- List view accent stripe clipped to rounded corners
- AutoBoks camera permission requested before the sheet opens

---

## 0.7 — 2026-06-19

### Added
- App icon updated on iOS and Android; Android splash screen shows Bokses icon
- BoksTalk — voice-to-item mode with silence timeout and optional read-back
- BoksTalk settings — silence timeout slider and Read Back toggle

### Changed
- App bar "Bokses" title renders as a gradient from primary to accent colour
- Box cards gradient across the full sorted list
- New Box button redesigned as a gradient pill
- Export filename uses compact timestamp; native save dialog used where available

---

## 0.6 — 2026-06-18

### Added
- Box sorting — date (oldest/newest) or name (A–Z / Z–A)
- Fragile label — yellow caution badge on boxes
- Web splash screen — shows Bokses icon while loading

### Changed
- Local storage — data now saves in the browser; no backend or Docker required
- Backend, Docker Compose, nginx config, and deploy script removed

### Fixed
- Android Gradle build output redirected to `/private/tmp/bokses-gradle`

---

## 0.5 — 2026-06-18

First versioned release milestone.

### Added
- Android and iOS platform support
- Configurable server URL in Settings (mobile)
- Comprehensive widget and unit test suite (89 tests)

### Changed
- Version scheme reset from `0.0.x` internal builds to `0.5`

---

## 0.4 — 2026-06-11

### Added
- Comprehensive widget and unit test suite (89 tests)
  - Model round-trip tests (Box, Item)
  - FakeDatabaseService CRUD, search, and cascade-delete tests
  - ImportExportService export payload and import round-trip tests
  - HomeScreen: empty state, grid, add/edit/delete box, search
  - BoxDetailScreen: empty state, item list, add/edit/delete item, navigation

---

## 0.3 — 2026-06-11

### Fixed
- Loading fix — API errors no longer hang the spinner

### Changed
- Redesigned app bar: gradient B logo, pill action buttons with divider

---

## 0.2 — 2026-06-11

### Added
- Version footer with changelog tooltip and full history page

### Fixed
- Web export now downloads a file directly
- Fixed export crash when server returns unexpected response

### Changed
- Title changed to capital-B Bokses, subtitle removed

---

## 0.1 — 2026-06-11

Initial versioned release.

### Added
- Server-side SQLite storage via FastAPI backend
- Docker Compose deployment with nginx reverse proxy
- Dark icon set as web favicon
- One-command deploy script
