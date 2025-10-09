#!/usr/bin/env sh
set -eu

if [ -n "${REMOTE_CONTAINERS:-}" ] || [ -n "${DEVCONTAINER:-}" ] ; then
  exec "$@" # inside the devcontainer
else # outside the devcontainer
  exec docker compose run --rm e621 sh -lc "$@"
fi