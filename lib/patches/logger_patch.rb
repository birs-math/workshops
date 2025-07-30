# lib/patches/logger_patch.rb
require "logger"

# Patch for Ruby 3.0 compatibility with Rails
# Explicitly define Logger within ActiveSupport::LoggerThreadSafeLevel
module ActiveSupport
  module LoggerThreadSafeLevel
    # Explicitly define Logger reference to avoid issues with Ruby 3.0
    Logger = ::Logger unless defined?(Logger)
  end
end