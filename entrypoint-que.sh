#!/bin/sh
set -e

# Wait for database to be ready
until nc -z -v -w30 db 5432
do
  echo "Waiting for database connection..."
  # wait for 5 seconds before check again
  sleep 5
done

# Try connecting to the web service, but don't fail if it's not available yet
echo "Trying to connect to web service..."
MAX_ATTEMPTS=10
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if nc -z -v -w2 web 8000; then
    echo "Web service is up!"
    break
  fi
  ATTEMPT=$((ATTEMPT+1))
  echo "Web service not ready yet, attempt $ATTEMPT/$MAX_ATTEMPTS. Waiting..."
  sleep 5
done

# Start the que worker
echo "Starting Que worker..."
exec bundle exec rake que:work
