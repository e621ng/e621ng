#!/usr/bin/env sh
echo "Running daily maintenance"
cd /app && bundle exec rake maintenance:daily
echo "Finished daily maintenance"
