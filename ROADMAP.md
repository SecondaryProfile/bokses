# Bokses — Roadmap

Ideas for later. Not scheduled, not in any order.

## Item history

Keep a log of what happens to each item, e.g.:

> 9-12-26 — Joe moved Drill from Box D to Garage Box

## Box sharing

- In Settings, a default sharing option for new boxes: **Just me**, **Everyone**, or **Select people**
- Per-box sharing, so certain boxes are only viewable by certain people

## Publish to GHCR

- Push built images to `ghcr.io/secondaryprofile/bokses` so users can
  `docker compose pull` instead of building locally
- Re-add a CI `publish` job (multi-arch build + push, gated on version tags)
- Set the GHCR package to public on first release
- Update the README self-hosting section and `docker-compose.yml` to use the
  published image once this is live
