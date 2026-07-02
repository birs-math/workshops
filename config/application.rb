require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Workshops
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    config.time_zone = "Mountain Time (US & Canada)"

    # Rails 5.2.8.1 switched ActiveRecord YAML columns to Psych safe_load, which rejects
    # classes not on this allowlist. Membership#invite_reminders is a Hash keyed by DateTime
    # (and Person#grants), so without these we get Psych::DisallowedClass on load (500s the
    # memberships page + crashes the reminder/stats/sync jobs). Allowlist keeps the hardening.
    config.active_record.yaml_column_permitted_classes = [
      Symbol, Date, Time, DateTime, BigDecimal,
      ActiveSupport::TimeWithZone, ActiveSupport::TimeZone,
      ActiveSupport::HashWithIndifferentAccess
    ]
  end
end
