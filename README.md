# Bokses

A bubbly box storage management app — know what's in every box.

Bokses is a **web-only** Flutter app. There are no mobile or desktop build
targets; the only output is a static bundle from `flutter build web`, meant to
be served by any web server or container.

## Requirements

- Flutter 3.x (stable channel)
- A Chromium-based browser for development — AutoBoks and BoksTalk use the Web
  Speech API, which Firefox and Safari do not implement.

## Running locally

```sh
flutter pub get
flutter run -d chrome
```

## Building

```sh
flutter build web --release
```

The bundle lands in `build/web/`. It is fully static — no backend, no server
component.

## Where data lives

Everything is client-side, per browser profile:

- **Boxes, items and settings** — `SharedPreferences`, backed by
  `localStorage`.
- **Photos** — stored inline as `data:` URIs, except web-search results, which
  are kept as remote URLs.
- **AI provider API keys** — `flutter_secure_storage`, which on web is
  AES-encrypted `localStorage`. That keeps keys out of plain storage and logs,
  but it is only as private as the browser profile: a shared machine is a
  shared key.
- **Debug log** — an in-memory rolling buffer for the current tab only.

Clearing site data wipes all of it, so use **Settings → Export** for backups.

## AI image recognition

Bokses has no server of its own. Image-recognition requests go straight from
the browser to whichever provider you configured (Gemini, Claude, or ChatGPT)
using your own API key. Note that this means those requests are subject to the
provider's CORS policy, and that the key is exposed to the browser — use a
key scoped to this purpose.

## Tests

```sh
flutter test
```

Tests run on the Dart VM rather than in a browser, which is why the download
helper is split across `lib/services/web_download.dart` (VM stub) and
`web_download_web.dart` (the real `dart:html` implementation), selected by a
conditional import.
