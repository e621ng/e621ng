#!/usr/bin/env sh
set -eu

if [ -n "${REMOTE_CONTAINERS:-}" ] || [ -n "${DEVCONTAINER:-}" ] ; then
  if [ "$#" -eq 1 ]; then
    exec "$1" # directly execute the command if no service is specified
  else
    service="$1"
    shift
    exec "$@" # inside the devcontainer, execute the command
  fi
else # outside the devcontainer
  service="$1"
  shift
  exec docker compose run --rm "$service" sh -lc "$@"
fi