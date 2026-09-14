# syntax=docker/dockerfile:1.7
#
# Bokses — one image: nginx serving the Flutter web app and proxying /api to
# the Dart API server, both running as an unprivileged user. Postgres runs in
# its own container (see docker-compose.yml).

# ── 1. Flutter web build ─────────────────────────────────────────────────────
# Flutter is installed from its git tag so the image builds with exactly the
# version the app is tested on (no prebuilt image exists for it yet).
FROM debian:trixie-slim AS web

ARG FLUTTER_VERSION=3.47.4

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}" \
    FLUTTER_SUPPRESS_ANALYTICS=true
RUN flutter config --no-analytics --no-cli-animations \
 && flutter precache --web --no-android --no-ios

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

# ── 2. API server build ──────────────────────────────────────────────────────
FROM dart:3.13 AS api

WORKDIR /server
COPY server/pubspec.yaml server/pubspec.lock ./
RUN dart pub get
COPY server/ ./
RUN dart pub get --offline \
 && mkdir -p /out \
 && dart compile exe bin/server.dart -o /out/bokses-server

# ── 3. Runtime ───────────────────────────────────────────────────────────────
# Same Debian release (trixie) as the dart image, so the AOT binary's system
# libraries match without copying anything over the base image's own.
FROM nginxinc/nginx-unprivileged:stable-trixie

LABEL org.opencontainers.image.title="Bokses" \
      org.opencontainers.image.description="Tidy up your life. Just put it in a box. Deal with it later or reorganize now." \
      org.opencontainers.image.source="https://github.com/SecondaryProfile/bokses"

# The nginx-unprivileged image already runs as its non-root "nginx" user.
# Switch back only long enough to install files.
USER root

COPY --from=api /out/bokses-server /usr/local/bin/bokses-server
COPY --from=web /app/build/web /usr/share/nginx/html
COPY --chmod=644 docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/bokses-entrypoint

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/api/health || exit 1

ENTRYPOINT ["/usr/local/bin/bokses-entrypoint"]
