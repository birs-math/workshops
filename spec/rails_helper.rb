# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'factory_bot_rails'
require 'faker'
require 'database_cleaner'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories.
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Removed the problematic Psych configuration line that caused NoMethodError.
# The Psych::DisallowedClass error might return, which will require a different fix
# compatible with Psych 3.x when it appears.


# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

#########################
# Optional: Pre-clean tables to avoid permission issues
# Only uncomment if still having issues after the other changes
# begin
#   ActiveRecord::Base.establish_connection
#   ActiveRecord::Base.connection.tables.each do |table|
#     ActiveRecord::Base.connection.execute("TRUNCATE #{table} CASCADE")
#   end
# rescue => e
#   puts "Warning: Could not pre-clean tables: #{e.message}"
# end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # Set to false - we'll use database_cleaner instead
  config.use_transactional_fixtures = false

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Configure database_cleaner to use truncation to avoid permission issues
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
    DatabaseCleaner.strategy = :truncation
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end