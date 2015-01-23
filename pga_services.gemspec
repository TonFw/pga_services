# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pga_services/version'

Gem::Specification.new do |spec|
  spec.name          = "pga_services"
  spec.version       = PGA::VERSION
  spec.authors       = ["Ilton Garcia dos Santos Silveira"]
  spec.email         = ["ilton_unb@hotmail.com"]
  spec.summary       = 'SOAP PGA Client'
  spec.description   = 'A lot of methods to use a simple call to integrate with the PGA'
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]


  #================== GEMs to build it GEM, so its improve the development ==============================
  # Base GEMs to build it gem
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 10.3", '>= 10.3.2'

  # RSpec for tests
  spec.add_development_dependency "rspec", "~> 3.1", '>= 3.1.0'
  # RSpec its helper
  spec.add_development_dependency "its", "~> 0.2", '>= 0.2.0'
  # Coverage
  spec.add_development_dependency 'simplecov', '~> 0.7', '>= 0.7.1'
  # Create readable attrs values
  spec.add_development_dependency 'faker', '~> 1.4', '>= 1.4.2'

  #================== GEMs to be used when it is called on a project ====================================
  # For real user operator IP (4GeoLoc)
  spec.add_dependency 'curb', "~> 0.8", '>= 0.8.6'
  # HTTP REST Client
  spec.add_dependency "rest-client", '~> 1.7', '>= 1.7.2'
  # SOAP Client
  spec.add_dependency 'savon', '~> 2.3.3'
  # Easy JSON create
  spec.add_dependency "multi_json", '~> 1.10', '>= 1.10.1'
  # To pretty print on console
  spec.add_dependency "colorize", '~> 0.7.3', '>= 0.7.3'
  # To work with the Rails Numeric for currency
  spec.add_dependency 'bigdecimal', '~> 1.2.5', '>= 1.2.5'
end
