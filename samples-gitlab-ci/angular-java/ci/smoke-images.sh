#!/bin/sh
set -eu
# Hooks are optional trusted project code, sourced to configure test dependencies.
# Set BACKEND_SMOKE_ENV_FILE to an env file and/or SMOKE_NETWORK in the setup hook.
cleanup() {
  docker rm -f ci-frontend ci-backend >/dev/null 2>&1 || true
  if [ -n "${SMOKE_CLEANUP_SCRIPT:-}" ]; then . "$SMOKE_CLEANUP_SCRIPT"; fi
}
trap cleanup EXIT
if [ -n "${SMOKE_SETUP_SCRIPT:-}" ]; then . "$SMOKE_SETUP_SCRIPT"; fi
set --
if [ -n "${SMOKE_NETWORK:-}" ]; then set -- "$@" --network "$SMOKE_NETWORK"; fi
if [ -n "${BACKEND_SMOKE_ENV_FILE:-}" ]; then set -- "$@" --env-file "$BACKEND_SMOKE_ENV_FILE"; fi
docker run -d --name ci-backend "$@" "$BACKEND_IMAGE"
docker run -d --name ci-frontend "$FRONTEND_IMAGE"
ready=false
for attempt in $(seq 1 60); do
  if docker exec ci-frontend wget -q -O /tmp/index.html "http://127.0.0.1:8080$ANGULAR_SMOKE_PATH" &&
     docker exec ci-backend bash -c '
       exec 3<>/dev/tcp/127.0.0.1/"$1"
       printf "GET %s HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n" "$2" >&3
       IFS= read -r status <&3
       case "$status" in *" 200 "*) exit 0;; *) exit 1;; esac
     ' probe "$BACKEND_PORT" "$BACKEND_SMOKE_PATH"; then
    docker cp ci-frontend:/tmp/index.html /tmp/image-index.html
    cmp .ci-dist/frontend/index.html /tmp/image-index.html
    ready=true
    break
  fi
  sleep 2
done
if [ "$ready" != true ]; then
  echo 'Image smoke check failed; inspect startup configuration and HTTP endpoint.' >&2
  exit 1
fi
