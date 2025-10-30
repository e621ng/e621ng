#!/usr/bin/env sh
set -eu

if [ -n "${REMOTE_CONTAINERS:-}" ] || [ -n "${DEVCONTAINER:-}" ] || [ -n "${CODESPACES:-}" ]; then
  if [ "$#" -eq 1 ]; then # for tests/rubocop, there are no extra args
    exec "$@"
  else
    shift
    exec "$@"
  fi
else # outside the devcontainer
  if [ "$#" -eq 1 ]; then  # for tests/rubocop, there are no extra args
    exec docker compose run --rm "$@"
  elif [ "$1" = "linter" ]; then # eslint breaks if you pass arguments
    exec docker compose run --rm "$1"
  else
    service="$1"
    shift
    exec docker compose run --rm "$service" sh -lc "$@"
  fi
fi