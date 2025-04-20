ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
require 'bundler/setup' # Set up gems listed in the Gemfile
require 'logger' # Add this line
# require_relative '../lib/patches/logger_patch' # Comment this line out for now