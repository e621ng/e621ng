#! /bin/sh
set -e
echo "Waiting for elastic to come up"
timeout 20 sh -c 'until nc -z elastic 9200; do sleep 1; done'

bundle exec rails test "$@"
