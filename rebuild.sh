#!/bin/sh
# Rebuilds and restarts Bokses from a local checkout: stops the stack, builds
# a fresh image from the current source, and brings it back up.
set -eu

docker compose down
docker compose build
docker compose up -d
