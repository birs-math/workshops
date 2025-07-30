# Ruby 3.0 compatibility patch for Rails logger
require "logger"

# Explicitly define Logger within ActiveSupport::LoggerThreadSafeLevel
module ActiveSupport
  module LoggerThreadSafeLevel
    # Explicitly define Logger reference to avoid issues with Ruby 3.0
    Logger = ::Logger unless defined?(Logger)
  end
end
