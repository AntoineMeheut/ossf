#!/bin/sh
set -eu
# CLI contract. Services must provide a startup/readiness hook instead.
docker run --rm "$APP_IMAGE" --help
