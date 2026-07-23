# frozen_string_literal: true

module FacterClient
  module Resources
    class Emisors
      def initialize(client)
        @client = client
      end

      def list
        @client.get('/emisores')
      end

      def get(rfc:)
        @client.get("/emisores/#{rfc}")
      end
    end
  end
end
