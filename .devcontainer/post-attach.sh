#!/bin/sh
set -eu

# Mark the workspace safe for Git operations run inside the container.
git config --global --add safe.directory /app

# Copy sample environment if one is not already present.
if [ ! -f /app/.env ]; then
  cp /app/.env.sample /app/.env
fi

# Ensure the local configuration file is kept in sync.
cp /app/docker/danbooru_local_config.rb /app/config/danbooru_local_config.rb

echo -e "\e[1;33mImportant:\e[0m if using devcontainers through GitHub Codespaces or similar services, it is \e[1mrecommended\e[0m to modify 'db/populate.rb' to use e926 or specify 'rating:s' in the post population\n\nFor help with the devcontainer, see .devcontainer/devcontainer.md\n"
