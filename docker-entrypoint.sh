#!/bin/bash

set -e

echo 'Waiting for a connection with postgres...'

until psql -h "postgres" -U "postgres" -c '\q' > /dev/null 2>&1; do
  sleep 1
done

echo 'Connected to postgres...'

bundle check || bundle install
bundle exec "$@"
