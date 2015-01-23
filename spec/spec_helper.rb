require 'bundler/setup'
require 'rest_client'
require './spec/helpers'

Bundler.setup

require 'simplecov'
SimpleCov.start do
end

# and any other gems you need
require 'pga_services'
require 'faker'

RSpec.configure do |c|
  # some (optional) config here
  c.include Helpers
end