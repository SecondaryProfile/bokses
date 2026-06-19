const String kFontFamily = 'Trebuchet MS';
const String kAppVersion = '0.1.2';

const kChangelog = [
  (
    version: '0.1.3',
    date: 'Unreleased',
    changes: [
      'List view for boxes with iOS-style swipe actions (rename / delete)',
      'Swipe actions on items inside a box',
      'Item labels — Fragile, Battery, Liquid — shown on items and propagated to box cards',
      'Instant Load setting skips animations for faster scrolling',
      'Box cards now display the box name at top instead of an icon',
      'Bigger search and menu controls in the app bar',
      'Version footer moved to Settings',
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
