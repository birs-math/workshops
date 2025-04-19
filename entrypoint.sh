#!/bin/bash
cd ${APP_HOME}

echo "Checking database connection..."
while ! nc -z db 5432; do
  sleep 1
done
echo "Connection to db 5432 port [tcp/*] succeeded!"

bundle check || bundle install

# Fix Rails logger issue by patching the problematic file
LOGGER_FILE=$(find vendor/bundle -path "*/active_support/logger_thread_safe_level.rb")
if [ -f "$LOGGER_FILE" ]; then
  echo "Patching Rails logger file at $LOGGER_FILE"
  # Add 'require "logger"' at the top of the file if not already there
  grep -q "require \"logger\"" "$LOGGER_FILE" || sed -i '1i require "logger"' "$LOGGER_FILE"
  # Add 'Logger = ::Logger' inside the module
  sed -i 's/module LoggerThreadSafeLevel/module LoggerThreadSafeLevel\n    Logger = ::Logger unless defined?(Logger)/g' "$LOGGER_FILE"
  echo "Rails logger file patched successfully"
fi

if [ "$#" -eq 0 ]; then
  echo "Starting Rails server..."
  rm -f ${APP_HOME}/tmp/pids/server.pid
  bundle exec rails server -b 0.0.0.0 -p 8000
else
  exec "$@"
fi