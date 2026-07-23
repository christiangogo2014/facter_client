# frozen_string_literal: true

module FacterClient
  class Configuration
    DEMO_URL = 'https://demo.facter.com.mx/api/ext/v1'
    PRODUCTION_URL = 'https://v2.facter.com.mx/api/ext/v1'

    attr_accessor :api_key, :environment, :timeout, :webhook_secret, :demo_url, :production_url

    def initialize
      @api_key        = ENV['FACTER_API_KEY']
      @environment    = (ENV['FACTER_ENVIRONMENT'] || 'demo').to_sym
      @timeout        = (ENV['FACTER_TIMEOUT'] || 30).to_i
      @webhook_secret = ENV['FACTER_WEBHOOK_SECRET']
      @demo_url       = ENV['FACTER_DEMO_URL'] || DEMO_URL
      @production_url = ENV['FACTER_PRODUCTION_URL'] || PRODUCTION_URL
    end

    def base_url
      case environment.to_sym
      when :production then production_url
      when :demo       then demo_url
      else
        raise ConfigurationError, "Unknown environment: #{environment}. Use :demo or :production"
      end
    end

    def valid?
      !api_key.nil? && !api_key.to_s.empty?
    end
  end
end
