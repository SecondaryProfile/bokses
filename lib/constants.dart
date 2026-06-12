const String kFontFamily = 'Trebuchet MS';
const String kAppVersion = '0.0.21';

const kChangelog = [
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
