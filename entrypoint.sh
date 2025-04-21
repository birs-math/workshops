#!/bin/bash
set -e

cd ${APP_HOME}
echo "Checking database connection..."
while ! nc -z db 5432; do
  sleep 1
done
echo "Connection to db 5432 port [tcp/*] succeeded!"

bundle check || bundle install

# We no longer need to patch the logger at runtime
# The patch is now applied via the logger_patch.rb file that's loaded in boot.rb

if [ "$#" -eq 0 ]; then
  echo "Starting Rails server..."
  rm -f ${APP_HOME}/tmp/pids/server.pid
  bundle exec rails server -b 0.0.0.0 -p 8000
else
  exec "$@"
fi