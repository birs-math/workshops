#!/bin/bash
set -e

# Signal handler function to forward signals to que process
handle_signal() {
  echo "Received signal, forwarding to que worker..."
  if [ -n "$QUE_PID" ]; then
    kill -$1 $QUE_PID 2>/dev/null || true
  fi
}

# Set up signal traps
trap 'handle_signal TERM' TERM
trap 'handle_signal INT' INT

# Wait for database to be ready
echo "Checking database connection..."
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

echo
echo "Running que worker..."

# Make sure we're in the right directory
cd /home/app/workshops

# Check if Gemfile.lock exists and Bundler is installed
if [ -f "Gemfile.lock" ] && command -v bundle >/dev/null 2>&1; then
  echo "Checking Gemfile dependencies..."
  bundle check || bundle install --jobs 4 --retry 3
fi

# Create a temporary initializer to force proper Que adapter loading
cat > /tmp/que_init.rb << 'EOL'
require 'rails/all'
require 'que'

begin
  puts "Attempting to initialize Que adapter..."
  if defined?(ActiveRecord) && Que.respond_to?(:adapter=)
    require 'que/adapters/active_record'
    Que.adapter = Que::Adapters::ActiveRecord
    puts "Initialized Que with ActiveRecord adapter (new style)"
  elsif defined?(ActiveRecord)
    Que.connection = ActiveRecord
    puts "Initialized Que with ActiveRecord connection (old style)"
  else
    puts "WARNING: ActiveRecord not available for Que initialization"
  end
rescue => e
  puts "Error initializing Que adapter: #{e.message}"
  puts e.backtrace.join("\n")
end
EOL

# Run the pre-initialization script
echo "Initializing Que adapter before starting worker..."
bundle exec rails runner /tmp/que_init.rb

# Run the que worker with a modified rake task approach
cat > /tmp/que_rake_override.rb << 'EOL'
namespace :que do
  desc "Start a Que worker with adapter initialization"
  task :work_safe => :environment do
    require 'que'
    
    begin
      # Force adapter initialization here
      if defined?(ActiveRecord) && Que.respond_to?(:adapter=)
        require 'que/adapters/active_record'
        Que.adapter = Que::Adapters::ActiveRecord
      elsif defined?(ActiveRecord)
        Que.connection = ActiveRecord
      else
        raise "ActiveRecord not available for Que"
      end
      
      # Configure Que
      Que.logger = Rails.logger
      Que.log_formatter = JSON if Que.respond_to?(:log_formatter=)
      
      # Set worker options
      worker_count = (ENV['QUE_WORKERS'] || 2).to_i
      poll_interval = (ENV['QUE_POLL_INTERVAL'] || 5).to_i
      
      # Start workers
      puts "Starting Que worker(s) with configuration:"
      puts "- Worker count: #{worker_count}"
      puts "- Poll interval: #{poll_interval} seconds"
      
      Que.worker_count = worker_count if Que.respond_to?(:worker_count=)
      
      # Start in async mode
      Que.mode = :async if Que.respond_to?(:mode=)
      
      # Keep process alive
      sleep
      
    rescue => e
      puts "ERROR starting Que worker: #{e.message}"
      puts e.backtrace.join("\n")
      exit 1
    end
  end
end
EOL

# Run our custom rake task
echo "Starting Que worker with adapter initialization..."
bundle exec rails runner /tmp/que_rake_override.rb &
QUE_PID=$!

# Log the PID for debugging
echo "Que worker started with PID: $QUE_PID"

# Wait for the que process to finish
wait $QUE_PID
