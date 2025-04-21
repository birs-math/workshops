source 'https://rubygems.org'
# Rails and core dependencies upgrade
gem 'rails', '6.1.0'  # Updated from '6.0.6.1'
gem 'pg', '1.1.3'
gem 'rack', ">= 2.2.3"
gem 'rack-cors', require: 'rack/cors'
# Force nokogiri to use Ruby platform to avoid glibc issues
gem 'nokogiri', force_ruby_platform: true
# Authentication & Authorization
gem 'bcrypt'
gem 'devise', '~> 4.8.1'  # Update to a version compatible with Ruby 3.0
gem 'devise-encryptable'
gem 'devise_invitable'
gem 'devise-jwt'
gem 'pundit'
# Asset pipeline and frontend
gem 'bootstrap', '~> 4.5.0'
gem 'coffee-rails'
gem 'font-awesome-rails'
gem 'jbuilder'
gem 'jquery-rails'
gem 'jquery-turbolinks'
gem 'momentjs-rails'
gem 'popper_js', '~> 1.16.0'
gem 'sassc-rails'
gem 'turbolinks'
gem 'uglifier'
gem 'webpacker', '~> 5.4'  # Updated to 5.4 for Rails 6
# Admin dashboard
gem "administrate", ">= 0.13.0"
# Background processing
gem 'que', '~> 2.2.1'
gem 'que-scheduler'
gem 'sucker_punch'
# Email handling
gem 'email_validator', '~> 1.6.0'
gem 'griddler'
gem 'griddler-mailgun'
gem 'mailgun-ruby'
# PDF generation
gem 'wicked_pdf'
gem 'wkhtmltopdf-binary'
# Templates and rendering
gem 'liquid'
# Storage and session handling
gem 'activerecord-session_store'
gem 'bootsnap'
gem 'paper_trail'
gem 'rails-settings-cached', '0.7.2'
# API and external services
gem 'rest-client'
# SSH and security
gem 'ed25519'
# Documentation
gem 'sdoc', '~> 2.0.0'  # Only change - pinned to work with psych 3.3.2
# Rails 6 and Ruby 3.0 compatibility gems
gem 'psych', '~> 3.3.2'
gem "dry-configurable", "0.9.0"
gem "dry-container", "0.7.2"
gem 'faraday-retry'
gem 'net-smtp', require: false
gem 'net-imap', require: false
gem 'net-pop', require: false
gem 'rails-html-sanitizer', '~> 1.4.4'
gem 'rubyzip', '~> 2.3.0'
# Server
gem 'passenger'
# Development and test environments
group :development, :test do
  gem 'byebug'
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'spring'
  gem 'sqlite3', '~> 1.4.0'  # Updated from 1.3.x
end
# Test-specific gems
group :test do
  gem 'capybara'
  gem 'database_cleaner'
  gem 'faker'
  gem 'rails-controller-testing'
  gem 'rubocop'
  # Removed rubocop-faker - causing conflicts
  gem 'selenium-webdriver'
  gem 'simplecov'
  gem 'simplecov-lcov'
end
# Production-specific gems
group :production do
  gem 'newrelic_rpm'
  gem 'rollbar'
end
# Development-specific gems
group :development do
  gem 'listen'
  gem 'bcrypt_pbkdf', '~> 1.0'
  gem 'capistrano', '~> 3.10', require: false
  gem 'capistrano-rails', '~> 1.4', require: false
  # Removed all pronto gems - they're causing dependency issues
  gem 'rbnacl', '~> 7.0'
  gem 'rubocop-rails'
  gem 'web-console'
end