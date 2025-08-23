# config/initializers/que.rb
Rails.application.config.to_prepare do
  require 'que'

  begin
    Rails.logger.info "Initializing Que adapter..."
    
    # Handle different Que versions
    if defined?(ActiveRecord)
      if Que.respond_to?(:adapter=)
        require 'que/adapters/active_record'
        Que.adapter = Que::Adapters::ActiveRecord
        Rails.logger.info "Initialized Que with ActiveRecord adapter (new style)"
      else
        Que.connection = ActiveRecord
        Rails.logger.info "Initialized Que with ActiveRecord connection (old style)"
      end
      
      # Configure logging
      Que.logger = Rails.logger
      Que.log_formatter = JSON if Que.respond_to?(:log_formatter=)
      
      # Other configuration as needed
      poll_interval = (ENV['QUE_POLL_INTERVAL'] || 5).to_i
      Que.poll_interval = poll_interval if Que.respond_to?(:poll_interval=)
    else
      Rails.logger.warn "ActiveRecord not available for Que initialization"
    end
  rescue => e
    Rails.logger.error "Error initializing Que: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
