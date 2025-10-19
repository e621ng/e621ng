#!/bin/sh
set -e

if [ -d "vendor/dtext" ] && [ "$LOCAL_DTEXT" = "true" ]; then
  echo "dtext: Recompiling..."
  cd vendor/dtext
  
  rm -f lib/dtext/dtext.so
  rm -rf tmp/
  
  bundle install --quiet
  bundle exec rake compile
  cd /app
  echo "dtext: Recompiled successfully"
fi

exec "$@"
