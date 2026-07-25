require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Workshops
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

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

    # Rails 7.1 defaults sanitize() to the HTML5 (Gumbo) parser, which raises
    # ArgumentError past 400 attributes on one element. Event custom fields hold
    # raw LaTeX, where "<" is a comparison operator: "$$a=x_0<x_1<\cdots<x_n=b$$"
    # parses as a <x_1> tag whose "attributes" are the rest of the field, 500ing
    # events#show for staff/organizers. HTML4 is the parser this app shipped on
    # through Rails 7.0; it truncates such fields at the first "<" rather than
    # raising. Revisit if custom fields ever stop carrying LaTeX.
    config.action_view.sanitizer_vendor = Rails::HTML4::Sanitizer
  end
end
