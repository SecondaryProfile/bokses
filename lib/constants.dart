const String kFontFamily = 'Trebuchet MS';
const String kAppVersion = '0.1.4';

const kChangelog = [
  (
    version: '0.1.4',
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
    version: '0.1.3',
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
    version: '0.1.2',
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
    version: '0.1.1',
    date: '2026-06-18',
    changes: [
      'Box sorting — date (oldest/newest) and name (A–Z / Z–A)',
      'Fragile label — mark boxes with a yellow caution badge',
      'Web splash screen shows Bokses icon',
      'Local storage — data saves in the browser, no backend required',
    ],
  ),
  (
    version: '0.1.0',
    date: '2026-06-18',
    changes: [
      'Android and iOS support',
      'Configurable server URL in Settings (mobile)',
      'Comprehensive test suite (89 tests)',
    ],
  ),
  (
    version: '0.0.22',
    date: '2026-06-11',
    changes: [
      'Loading fix — API errors no longer hang the spinner',
      'Redesigned app bar: gradient B logo, pill action buttons with divider',
    ],
  ),
  (
    version: '0.0.21',
    date: '2026-06-11',
    changes: [
      'Version footer with changelog tooltip and full history page',
      'Title changed to capital-B Bokses, subtitle removed',
      'Web export now downloads a file directly',
      'Fixed export crash when server returns unexpected response',
    ],
  ),
  (
    version: '0.0.20',
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
