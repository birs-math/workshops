#!/bin/sh
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /home/app/workshops/tmp/pids/server.pid

# Wait for database to be ready
until nc -z -v -w30 db 5432
do
  echo "Waiting for database connection..."
  # wait for 5 seconds before check again
  sleep 5
done

# We're already running as the app user (from Dockerfile)
# Run bundle if needed
if [ -f Gemfile ] && [ ! -d vendor/bundle ]; then
  bundle check || bundle install --jobs 4
fi

# Skip Yarn - it's causing permission issues
# if [ -f yarn.lock ]; then
#   yarn install --check-files
# fi

# Run migrations if neededRUN echo "Setting system timezone to America/Edmonton..." && \
    export DEBIAN_FRONTEND=noninteractive && \
    ln -fs /usr/share/zoneinfo/America/Edmonton /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata
bundle exec rake db:migrate 2>/dev/null || bundle exec rake db:setup

# Start Rails server directly (don't try to use /sbin/my_init)
echo "Starting Rails server on port 8000..."
exec bundle exec rails server -b 0.0.0.0 -p 8000
