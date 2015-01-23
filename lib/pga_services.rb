require "pga_services/version"

module PGA
  # Gem files
  [:version, :services].each { |lib| require "pga_services/#{lib}" }

  def self.get_services
    @config_services = YAML.load_file(__FILE__ + 'configs/services.yml')
  end
end
