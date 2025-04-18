#!/bin/bash
rm -f /home/app/workshops/tmp/pids/server.pid
# Fix RVM and Ruby setup in entrypoint
source /usr/local/rvm/scripts/rvm
rvm use 2.7.7 --default
# Change to application directory
cd ${APP_HOME}
# Wait for database
echo "Checking database connection..."
while ! nc -z db 5432; do
  sleep 1
done
echo "Connection to db 5432 port [tcp/*] succeeded!"
# Install bundler if not already installed
echo "Installing bundler..."
gem list -i bundler -v 2.4.22 || gem install bundler -v 2.4.22
# Make sure we're using the right Ruby and Bundler
echo "Setting up environment..."
export PATH="$PATH:/usr/local/rvm/rubies/ruby-2.7.7/bin:/usr/local/rvm/gems/ruby-2.7.7/bin"
export GEM_HOME="/usr/local/rvm/gems/ruby-2.7.7"
export GEM_PATH="/usr/local/rvm/gems/ruby-2.7.7:/usr/local/rvm/gems/ruby-2.7.7@global"
# Run the command but don't use exec so we can keep the container running
echo "Running command: $@"
"$@" || true
echo "Rails application exited, keeping container alive for debugging"
sleep infinity
