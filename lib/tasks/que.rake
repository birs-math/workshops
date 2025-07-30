# lib/tasks/que.rake
namespace :que do
  desc "Start a Que worker"
  task work: :environment do
    require 'que'
    
    # Handle different Que versions with verbose logging
    puts "Starting Que worker in rake task"
    
    # Force adapter initialization here
    if defined?(ActiveRecord) && Que.respond_to?(:adapter=)
      require 'que/adapters/active_record'
      Que.adapter = Que::Adapters::ActiveRecord
      puts "Initialized Que with ActiveRecord adapter (new style)"
    elsif defined?(ActiveRecord)
      Que.connection = ActiveRecord
      puts "Initialized Que with ActiveRecord connection (old style)"
    else
      puts "ActiveRecord not available for Que"
      raise "ActiveRecord not available for Que initialization"
    end
    
    # Configure logging
    Que.logger = Rails.logger
    Que.log_formatter = JSON if Que.respond_to?(:log_formatter=)
    
    # Set worker options
    worker_count = (ENV['QUE_WORKERS'] || 2).to_i
    puts "Setting worker count to #{worker_count}"
    Que.worker_count = worker_count if Que.respond_to?(:worker_count=)
    
    # Start in async mode
    puts "Starting Que in async mode"
    Que.mode = :async if Que.respond_to?(:mode=)
    
    # Keep process alive
    sleep
  end
end
