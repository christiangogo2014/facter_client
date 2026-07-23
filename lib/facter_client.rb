# frozen_string_literal: true

require_relative 'facter_client/version'
require_relative 'facter_client/configuration'
require_relative 'facter_client/errors'
require_relative 'facter_client/client'
require_relative 'facter_client/cfdi'
require_relative 'facter_client/resources/cfdis'
require_relative 'facter_client/resources/emisors'

module FacterClient
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
      @client = nil
      @cfdis = nil
      @emisors = nil
    end

    def client
      @client ||= Client.new(configuration)
    end

    def cfdis
      @cfdis ||= Resources::Cfdis.new(client)
    end

    def emisors
      @emisors ||= Resources::Emisors.new(client)
    end

    def stamp(emisor_rfc:, cfdi:, **opts)
      cfdis.stamp(emisor_rfc: emisor_rfc, cfdi: cfdi, **opts)
    end

    def validate(emisor_rfc:, cfdi:, **opts)
      cfdis.validate(emisor_rfc: emisor_rfc, cfdi: cfdi, **opts)
    end

    def cancel(uuid:, motivo:, folio_sustitucion_uuid: nil)
      cfdis.cancel(uuid: uuid, motivo: motivo, folio_sustitucion_uuid: folio_sustitucion_uuid)
    end

    def cancelation_status(uuid:)
      cfdis.cancelation_status(uuid: uuid)
    end

    def get_xml(uuid:)
      cfdis.get_xml(uuid: uuid)
    end

    def get_pdf(uuid:)
      cfdis.get_pdf(uuid: uuid)
    end

    def list_emisors
      emisors.list
    end

    def get_emisor(rfc:)
      emisors.get(rfc: rfc)
    end

    def verify_webhook_signature(payload:, signature:)
      return false if signature.nil? || payload.nil?

      secret = configuration.webhook_secret
      raise ConfigurationError, 'webhook_secret is required for signature verification' if secret.nil?

      expected = 'sha256=' + OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('sha256'),
        secret,
        payload
      )

      Rack::Utils.secure_compare(expected, signature) rescue fixed_time_compare(expected, signature)
    end

    private

    def fixed_time_compare(a, b)
      return false if a.bytesize != b.bytesize

      l = a.unpack("C*")
      r = 0
      i = -1
      b.each_byte { |v| r |= v ^ l[i += 1] }
      r.zero?
    end
  end
end
