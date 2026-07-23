# frozen_string_literal: true

module FacterClient
  module Resources
    class Cfdis
      def initialize(client)
        @client = client
      end

      def stamp(emisor_rfc:, cfdi:, external_ref: nil, fecha_emision: nil, idempotency_key: nil)
        body = {
          emisor_rfc: emisor_rfc,
          external_ref: external_ref,
          fecha_emision: fecha_emision,
          cfdi: cfdi
        }

        @client.post('/cfdis', body: body, idempotency_key: idempotency_key)
      end

      def validate(emisor_rfc:, cfdi:, external_ref: nil, fecha_emision: nil)
        body = {
          emisor_rfc: emisor_rfc,
          external_ref: external_ref,
          fecha_emision: fecha_emision,
          cfdi: cfdi
        }

        @client.post('/cfdis/validate', body: body, idempotency_key: false)
      end

      def cancel(uuid:, motivo:, folio_sustitucion_uuid: nil)
        body = {
          motivo: motivo,
          folio_sustitucion_uuid: folio_sustitucion_uuid
        }.compact

        @client.post("/cfdis/#{uuid}/cancelacion", body: body)
      end

      def cancelation_status(uuid:)
        @client.get("/cfdis/#{uuid}/cancelacion")
      end

      def get_xml(uuid:)
        @client.get_raw("/cfdis/#{uuid}/xml")
      end

      def get_pdf(uuid:)
        @client.get_raw("/cfdis/#{uuid}/pdf")
      end
    end
  end
end
