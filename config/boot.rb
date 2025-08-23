ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
require 'bundler/setup' # Set up gems listed in the Gemfile
require 'logger' # Ensure logger is required early [cite: 145]
require_relative '../lib/patches/logger_patch' # Load the patch created in Dockerfile [cite: 145]