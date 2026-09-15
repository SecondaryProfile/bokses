# Bokses — Changelog

## 0.23 — 2026-09-14

- New "Report a Bug" option in the sidebar — prompts for a title and steps
  to reproduce, then opens a prefilled GitHub issue in a new tab for you
  to review and submit yourself. No server component, no stored GitHub
  token — nothing is sent until you approve it on GitHub's own page.

---

## 0.22 — 2026-09-14

- Auto-fill photos (PIAB) is temporarily turned off — it now shows a
  "Coming Soon!" message instead of searching, while a more reliable photo
  source is worked out (tracked in #5)

---

## 0.21 — 2026-09-14

- The About page no longer shows a gradient box icon above the Bokses
  wordmark
- Auto-fill-photos (PIAB) is more reliable: spaced-out, randomized request
  timing instead of a tight burst, and it now stops early with a clear
  message instead of quietly failing on every remaining item once
  DuckDuckGo starts rate-limiting
- Failed photo searches during auto-fill are now logged to Settings →
  Debug Log instead of failing silently

---

## 0.19 — 2026-09-14

- Fixed and greatly expanded the test suite:
  - Client: rewrote the database-service tests against the current
    server-backed architecture (mocked HTTP instead of the old
    SharedPreferences assumptions), added a full auth-flow e2e suite
    (setup, sign-in, sign-up, account management) against a fake in-memory
    API, and added unit tests for the greeting service
  - Server: added a full test suite (server/test/) covering setup, auth,
    rate limiting, account management, and boxes/items — run against a
    real Postgres — plus unit tests for password hashing and the login
    rate limiter
  - Fixed a layout overflow in the box-empty-state screen surfaced by the
    new coverage, during the box-open/close animation
- CI runs and enforces both suites again (previously disabled); a GitHub
  branch-protection rule on `main` now requires all three CI checks to
  pass before a pull request can merge
- Total line coverage: 59.5%

---

## 0.18 — 2026-09-14

- The clover auto-fill-photos button in a box's app bar now reads "PIAB" on
  a fixed green/black design that stays consistent on every theme, and its
  confirmation dialog is titled "Pic In a Box!"
- Home screen box/item counts are now plain text separated by a "|" instead
  of pill badges
- The Bokses wordmark on the home screen is bolder
- A box's item list scales its column count to the screen width instead of
  a fixed single column, so wide screens show multiple items per row
  instead of one skinny row with empty space beside it
- Home screen icons now stay legible against a Solid background color of
  any shade, instead of blending into it
- The Solid background color picker now offers 5 clearly distinct colors
  instead of 12 similar dark/light shades
- The sidebar now greets you by name with one of 20 rotating variations
  instead of always showing "Bokses", and its avatar shows your initial
  instead of a fixed "B"
- The sidebar version line now reads "Using Bokses v0.18"

---

## 0.17 — 2026-09-13

- Importing now asks whether to add the file's boxes and items to what's
  already here, or replace everything on the instance with the imported data

---

## 0.16 — 2026-09-13

- Box grid now scales its column count to the screen width instead of a fixed
  3 columns, so tiles stay a reasonable size on ultrawide monitors instead of
  stretching huge
- Bokses wordmark on the home screen is bigger and more spaced out
- After creating the root account, you're asked whether you want to import an
  existing Bokses export
- "Allow sign-ups" now defaults to on for new instances
- Changelog, settings, home screen controls, and about page cards use the
  same border thickness as box tiles

---

## 0.15 — 2026-09-13

Rollback and cleanup.

- Reverted GHCR image publishing — CI no longer builds or pushes images;
  self-hosting is git clone + `docker compose up -d --build`
- Removed the `publish` CI job and the tag-triggered release workflow
- README and `docker-compose.yml` updated to match; GHCR distribution moved
  to the roadmap for later

---

## 0.14 — 2026-09-14

- Server-backed accounts — Postgres replaces browser-local storage; everyone
  on the instance signs in and shares the same boxes
- Root account manages everyone else's accounts, and can turn self-service
  sign-ups on or off
- Passwords hashed with Argon2id (19 MiB, 2 iterations); session tokens are
  random 256-bit values, stored only as a SHA-256 hash
- Docker Compose deployment: nginx + a Dart API server + Postgres, published
  to GHCR

---

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
