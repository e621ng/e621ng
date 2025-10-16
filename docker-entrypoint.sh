#!/bin/sh
set -e

if [ -d "vendor/dtext_rb" ] && [ "$LOCAL_DTEXT" = "true" ]; then
  echo "dtext_rb: Recompiling..."
  cd vendor/dtext_rb
  
  rm -f lib/dtext/dtext.so
  rm -rf tmp/
  
  bundle install --quiet
  bundle exec rake compile
  cd /app
  echo "dtext_rb: Recompiled successfully"
fi

exec "$@"
