#!/usr/bin/env sh
set -eu

if [ -n "${REMOTE_CONTAINERS:-}" ] || [ -n "${DEVCONTAINER:-}" ] || [ -n "${CODESPACES:-}" ]; then
  if [ "$#" -eq 1 ]; then # for tests/rubocop, there are no extra args
    exec "$@"
  else
    service="$1"
    shift
    if [ "$service" = "tests" ]; then
      export RAILS_ENV=test
    fi
    exec "$@"
  fi
else # outside the devcontainer
  if [ "$#" -eq 1 ]; then  # for tests/rubocop, there are no extra args
    exec docker compose -p "${COMPOSE_PROJECT_NAME:-e621ng}" run --rm "$@"
  elif [ "$1" = "linter" ]; then # eslint breaks if you pass arguments
    exec docker compose -p "${COMPOSE_PROJECT_NAME:-e621ng}" run --rm "$1"
  else
    service="$1"
    shift
    exec docker compose -p "${COMPOSE_PROJECT_NAME:-e621ng}" run --rm "$service" sh -lc "$@"
  fi
fi
