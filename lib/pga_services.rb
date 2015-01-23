require 'base64'
require 'savon'
require 'singleton'
require "pga_services/version"

module PGA
  # Gem files
  [:version, :hash, :services].each { |lib| require "pga_services/#{lib}" }
end
