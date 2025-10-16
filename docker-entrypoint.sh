#!/bin/sh
set -e

<<<<<<< HEAD
if [ -d "vendor/dtext" ] && [ "$LOCAL_DTEXT" = "true" ]; then
  echo "dtext: Recompiling..."
  cd vendor/dtext
=======
if [ -d "vendor/dtext_rb" ] && [ "$USE_LOCAL_DTEXT" = "true" ]; then
  echo "dtext_rb: Recompiling..."
  cd vendor/dtext_rb
>>>>>>> e54e14ab1 ([DText] Allow for the usage of a local dtext_rb gem)
  
  rm -f lib/dtext/dtext.so
  rm -rf tmp/
  
  bundle install --quiet
  bundle exec rake compile
  cd /app
<<<<<<< HEAD
  echo "dtext: Recompiled successfully"
=======
  echo "dtext_rb: Recompiled successfully"
>>>>>>> e54e14ab1 ([DText] Allow for the usage of a local dtext_rb gem)
fi

exec "$@"
