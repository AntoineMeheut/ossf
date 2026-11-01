#!/bin/sh
set -eu
docker run --rm "$APP_IMAGE" --help
