# Defines our constants
RACK_ENV = ENV['RACK_ENV'] ||= 'development' unless defined?(RACK_ENV)
PADRINO_ROOT = File.expand_path('..', __dir__) unless defined?(PADRINO_ROOT)

# Load our dependencies
require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
require 'open-uri'
require 'active_support/all'
require 'telegram/bot'
Bundler.require(:default, RACK_ENV)

Padrino.load!

Mongoid.load!("#{PADRINO_ROOT}/config/mongoid.yml")
Mongoid.raise_not_found_error = false

Delayed::Worker.max_attempts = 1

Airrecord.api_key = ENV['AIRTABLE_API_KEY']

Pocket.configure do |config|
  config.consumer_key = ENV['POCKET_CONSUMER_KEY']
end
