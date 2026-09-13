const String kFontFamily = 'Trebuchet MS';
const String kAppVersion = '0.13';

const kChangelog = [
  (
    version: '0.13',
    date: '2026-09-13',
    changes: [
      'More tests, with a coverage check in CI',
      'Fixed a few AI provider bugs the new tests caught',
    ],
  ),
  (
    version: '0.12',
    date: '2026-09-13',
    changes: [
      'Model Hub replaced with AI Provider — connect your own Gemini, Claude, or ChatGPT API key for image recognition instead of downloading on-device models',
      'API keys are encrypted at rest in browser storage and never leave your browser except as part of a direct, user-initiated identify request',
      'Image recognition requests go straight from your browser to your chosen AI provider over HTTPS — no Bokses server is ever involved',
      'On-device ONNX model hub, downloads, and the small/medium/large tiers removed',
      'Bokses is now a web-only app — Android, iOS, macOS, Windows and Linux targets removed',
      'SysML architecture model and the requirements export tool removed',
    ],
  ),
  (
    version: '0.10',
    date: '2026-06-23',
    changes: [
      'Four-tier AI model hub — Small (MobileNet V3 Large), Medium (EfficientNet-Lite4), Large (ViT-B/16), XL (OpenCLIP ViT-L/14) — downloadable on demand from Settings',
      'ONNX Runtime support alongside TFLite — Large and XL models run via on-device ONNX inference',
      'Internet image search — find and set item photos from the web in the add or edit item dialog',
      'Bulk photo fill — one button in a box fills all photo-less items from a web image search',
      'Web-sourced photos marked with a globe badge to distinguish them from camera captures',
      'Refreshed app icon across all Android screen densities',
      'Bokses wordmark on the home screen now has an outline visible on any background or theme',
      'Box card border thickness unified — grid cards now match list tiles',
      'Edit item dialog redesigned: full-width photo area, Camera / Find online / Remove action row, labels in their own bordered section',
      'View mode toggle re-enable time reduced from 2.5 s to 1 s',
    ],
  ),
  (
    version: '0.9',
    date: '2026-06-22',
    changes: [
      'Swipe right on items to reveal a yellow Move button — moves the item to another box via a centered popup',
      'Move to Box redesigned as a popup dialog instead of a bottom sheet',
      'Item and box swipe menus are now iOS-style — only one open at a time, closes when swiping another row',
      'Item card borders match the gradient color of their parent box',
      'Photo and label picker shown side-by-side in add and edit item dialogs',
      'AutoBoks front/rear camera toggle button in the live preview',
      'AutoBoks snap sound and photo capture now fire simultaneously',
      'Search bar gets an opaque background when active on custom photo backgrounds',
      'Swipe actions show the correct corner color (blue for edit/delete side, yellow for move side)',
    ],
  ),
  (
    version: '0.8',
    date: '2026-06-19',
    changes: [
      'AutoBoks — hands-free voice-to-item mode with automatic photo capture; say an item name, a ding fires after the silence window, and the back camera takes a photo automatically',
      'Background setting — Default, Gradient, Photo (with blur slider), or Solid color; applies full-bleed behind the home screen',
      'Move to Box — three-dot menu on any item lets you move it to another box with one tap',
      'List view for boxes — toggle between grid and list in the summary bar',
      'iOS-style swipe actions on box list rows and item rows — short swipe reveals Edit / Delete; full swipe deletes with an undo toast',
      'Item labels — Fragile, Battery, Liquid — shown on items and propagated to box cards and list tiles',
      'Instant Load setting — skips fade-in animations so content appears immediately',
      'Import progress dialog — blocking modal with a progress bar during data import',
      'Box descriptions shown in list view and as a subtitle in the detail screen',
      'Animated app launch splash screen',
      'Settings screen redesigned with grouped sections',
    ],
  ),
  (
    version: '0.7',
    date: '2026-06-19',
    changes: [
      'BoksTalk — voice-to-item mode; speak an item name and it auto-adds after silence',
      'BoksTalk settings — adjustable silence timeout and optional read-back',
      'Gradient UI — title, box cards, and New Box button all blend between theme colors',
      'App icon updated on iOS and Android; Android splash screen shows Bokses icon',
      'Export saves directly to the file system with a timestamped filename',
    ],
  ),
  (
    version: '0.6',
    date: '2026-06-18',
    changes: [
      'Box sorting — date (oldest/newest) and name (A–Z / Z–A)',
      'Fragile label — mark boxes with a yellow caution badge',
      'Web splash screen shows Bokses icon',
      'Local storage — data saves in the browser, no backend required',
    ],
  ),
  (
    version: '0.5',
    date: '2026-06-18',
    changes: [
      'Android and iOS support',
      'Configurable server URL in Settings (mobile)',
      'Comprehensive test suite (89 tests)',
    ],
  ),
  (
    version: '0.4',
    date: '2026-06-11',
    changes: [
      'Comprehensive widget and unit test suite (89 tests)',
      'Model round-trip tests, FakeDatabaseService CRUD and search tests',
      'ImportExportService export payload and import round-trip tests',
      'HomeScreen and BoxDetailScreen widget tests',
    ],
  ),
  (
    version: '0.3',
    date: '2026-06-11',
    changes: [
      'Loading fix — API errors no longer hang the spinner',
      'Redesigned app bar: gradient B logo, pill action buttons with divider',
    ],
  ),
  (
    version: '0.2',
    date: '2026-06-11',
    changes: [
      'Version footer with changelog tooltip and full history page',
      'Title changed to capital-B Bokses, subtitle removed',
      'Web export now downloads a file directly',
      'Fixed export crash when server returns unexpected response',
    ],
  ),
  (
    version: '0.1',
    date: '2026-06-11',
    changes: [
      'Initial versioned release',
      'Server-side SQLite storage via FastAPI backend',
      'Docker Compose deployment with nginx reverse proxy',
      'Dark icon set as web favicon',
      'One-command deploy script',
    ],
  ),
];
