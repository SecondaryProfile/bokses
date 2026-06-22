# Bokses — Changelog

## 0.1.4 — 2026-06-22

### Added
- Swipe right on items to reveal a yellow **Move** button — opens a centered popup to move the item to another box
- AutoBoks front/rear camera toggle button overlaid on the live preview; tap to switch lenses mid-session
- Item card borders now match the gradient color of their parent box (the box's position in the gradient determines the item border color)

### Changed
- Move to Box redesigned as a centered popup dialog instead of a bottom sheet
- Item and box swipe menus now follow iOS single-open behaviour — opening one automatically closes any other
- AutoBoks: snap sound and photo capture fire simultaneously via `Future.wait` instead of sequentially; removes the perceptible delay between the audio cue and the shutter
- Photo and label picker shown side-by-side in the add and edit item dialogs
- Search bar gets a solid surface background when active, ensuring text is legible over any custom photo background
- Swipe action corner pockets show the correct color — blue on the edit/delete side, yellow on the move side

### Fixed
- Swipe action buttons restored to standard iOS-style rectangles after experimental edge-extension attempts
- Swipe corner pockets no longer show white when an item is revealed; a hard-stop gradient ensures each side shows its action color

---

## 0.1.3 — 2026-06-19

### Added
- List view for the home screen — toggle between grid and list with the button in the summary bar
- iOS-style swipe actions on box list rows and item rows: short swipe reveals Edit / Delete; full swipe deletes immediately with an undo toast
- Item labels — Fragile (yellow/black stripes), Battery (black→red gradient), Liquid (blue polkadots) — added via a Labels button in the add/edit item sheet
- Box cards and list tiles show any labels present on their items
- Instant Load setting (Performance → Settings) — skips fade-in animations so content appears immediately; on by default
- Animated splash screen — white background, app icon scales in with a bounce animation before fading into the home screen; Android native splash colour updated to white
- Import progress dialog — blocking modal with a progress bar while data imports, preventing interaction until complete
- Box descriptions shown below the name in list view and as a subtitle under the app bar in the per-box detail view
- **AutoBoks** replaces BoksTalk — hands-free voice-to-item mode now with automatic photo capture: say an item name, a ding fires after the silence window, the back camera captures a photo automatically, and the item is added with that photo attached
- AutoBoks live camera preview shown in the sheet so you can frame the item before speaking
- Camera toggle in AutoBoks settings — off reverts to pure voice-to-name mode (no ding, no capture)
- AutoBoks intro dialog updated to explain the camera flow; mic-only variant shown when camera is disabled
- **Background** setting — choose between Default, Gradient (theme colours top-left → bottom-right), Photo (pick from library, with blur slider), or Solid (12 preset colour swatches); background applies full-bleed behind the home screen
- **Move to Box** — three-dot menu on any item now includes "Move to Box"; tapping opens a sheet listing all other boxes with their item counts; one tap moves the item and shows a confirmation toast
- New Box button outline — thin white border on the gradient FAB so it reads clearly against any background

### Changed
- Settings screen redesigned with iOS-style grouped cards and consistent icon-badge rows; sections reordered to General → Background → AutoBoks → Performance → Computer Vision
- App bar "Bokses" title enlarged (26 → 30 pt); action button icons and padding increased
- Delete All Data and per-item Delete are always red regardless of active colour theme
- Box deletion via popup menu and swipe-reveal Delete button now uses the same instant-delete + undo-toast pattern as full-swipe; confirmation dialog removed for consistency
- New Box FAB has a white outline so it reads clearly against custom backgrounds
- Android `compileSdk` set explicitly to 36 (required by CameraX 1.5 and current AndroidX libraries)

### Fixed
- Undo toast after swipe-delete no longer stacks indefinitely when items are deleted in quick succession
- Import progress dialog reliably appears for all import sizes (race condition caused it to pop before rendering for small files)
- List view accent stripe now clipped to the card's rounded corners (`clipBehavior: Clip.antiAlias`)
- AutoBoks camera permission now requested while `BoxDetailScreen` is fully visible, before the sheet opens — fixes silent failure on Android where the system dialog could not interrupt a bottom-sheet animation
- Camera init errors surface the actual error message instead of a generic "Camera unavailable"

---

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
