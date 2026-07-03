source 'https://rubygems.org'

ruby '3.2.8'

gem 'activerecord-session_store'
# gem "administrate", ">= 0.13.0"
gem 'bcrypt'
gem 'bootsnap'
gem 'bootstrap', '~> 4.5.0'
gem 'coffee-rails'
gem 'devise'
gem 'devise-encryptable'
gem 'devise_invitable'
gem 'devise-jwt'
gem 'dry-configurable', '~> 0.9.0'
gem 'ed25519'
gem 'email_validator', '~> 1.6.0'
gem 'font-awesome-rails'
gem 'griddler'
gem 'griddler-mailgun'
gem 'jbuilder'
gem 'jquery-rails'
gem 'jquery-turbolinks'
gem 'liquid'
gem 'listen'
gem 'mailgun-ruby'
gem 'momentjs-rails'
gem 'paper_trail'
# 6.0.15+ required on Ruby 3.2 (6.0.12's own platform_info uses File.exists?,
# removed in 3.2). Newer passenger downloads a fresh nginx engine: the untracked
# per-env nginx.conf.erb must NOT contain 'ssl off;' (removed 2026-07-01).
gem 'passenger', '~> 6.0.15'
gem 'pg', '~> 1.5'
gem 'popper_js', '~> 1.16.0'
# psych stays at 3.x even on Ruby 3.1 (which bundles psych 4): psych 4 makes
# YAML.load safe-by-default, and rails-settings-cached 0.7.2 raw-YAML.loads its
# value column (bypassing AR's yaml_column_permitted_classes) -> DisallowedClass
# on every Setting read. Unblock when rails-settings-cached >= 2.x lands (Phase 5).
gem 'psych', '~> 3.3'
gem 'pundit'
gem 'que', '~> 2.4'
gem 'que-scheduler'
gem 'rack', ">= 2.2.3"
gem 'rack-cors', require: 'rack/cors'
gem 'rails', '~> 7.1.5'
gem 'rails-settings-cached', '0.7.2'
gem 'rest-client'
gem 'sassc-rails'
gem 'sdoc', group: :doc
gem 'sucker_punch'
gem 'turbolinks'
gem 'terser'
gem 'webpacker', '~> 5.x'
gem 'wicked_pdf'
gem 'wkhtmltopdf-binary'

group :development, :test do
  gem 'byebug'
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'spring'
  gem 'sqlite3', '~> 1.7'
end

group :test do
  gem 'capybara'
  gem 'database_cleaner'
  gem 'faker'
  gem 'rails-controller-testing'
  gem 'rubocop'
  gem 'rubocop-faker'
  gem 'selenium-webdriver'
  gem 'simplecov'
  gem 'simplecov-lcov'
end

group :production do
  gem 'newrelic_rpm'
  gem 'rollbar'
end

group :development do
  gem 'bcrypt_pbkdf', '~> 1.0'
  gem 'capistrano', '~> 3.10', require: false
  gem 'capistrano-rails', '~> 1.4', require: false
  gem 'rbnacl', '~> 7.0'
  gem 'rubocop-rails'
  gem 'web-console'
end
# Pins forced by the Rails 6.0 bump — each names its unblock condition:
# dry-container/dry-auto_inject 0.9+ break devise-jwt's warden-jwt_auth 0.5;
# revisit when devise-jwt is bumped (planned with dry-configurable 1.x, Phase 5).
gem 'dry-container', '~> 0.8.0'
gem 'dry-auto_inject', '~> 0.8.0'
# administrate 1.0 removes valid_action?/routes used by our dashboards;
# held at 0.16 until dashboards are migrated to the 1.x API.
gem 'administrate', '~> 0.16.0'
