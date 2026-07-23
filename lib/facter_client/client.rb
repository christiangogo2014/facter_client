# frozen_string_literal: true

require 'faraday'
require 'json'
require 'securerandom'

module FacterClient
  class Client
    attr_reader :config

    def initialize(config = FacterClient.configuration)
      @config = config
      validate_configuration!
    end

    def get(path, params: nil)
      request(:get, path, params: params)
    end

    def post(path, body:, idempotency_key: nil)
      request(:post, path, body: body, idempotency_key: idempotency_key)
    end

    def put(path, body:, idempotency_key: nil)
      request(:put, path, body: body, idempotency_key: idempotency_key)
    end

    def get_raw(path)
      response = connection.get(normalize_path(path)) do |req|
        req.headers['Authorization'] = "Bearer #{config.api_key}"
      end

      handle_response(response)
      response.body
    end

    private

    def request(method, path, body: nil, params: nil, idempotency_key: nil)
      response = connection.send(method, normalize_path(path)) do |req|
        req.headers['Authorization'] = "Bearer #{config.api_key}"
        req.headers['Content-Type'] = 'application/json'
        req.headers['Idempotency-Key'] = idempotency_key || SecureRandom.uuid if idempotency_key != false
        req.params = params if params
        req.body = body.to_json if body
      end

      handle_response(response)
      parse_body(response.body)
    end

    def normalize_path(path)
      path.to_s.sub(/^\//, '')
    end

    def connection
      @connection ||= Faraday.new(url: config.base_url) do |conn|
        conn.options.timeout = config.timeout
        conn.adapter Faraday.default_adapter
      end
    end

    def handle_response(response)
      case response.status
      when 200..299
        nil
      when 401, 403
        raise AuthenticationError.new(extract_message(response), code: extract_code(response), response: response)
      when 404
        raise NotFoundError.new(extract_message(response), code: extract_code(response), response: response)
      when 409
        code = extract_code(response)
        if code == 'IDEMPOTENCY_CONFLICT' || code == 'IDEMPOTENCY_IN_FLIGHT'
          raise IdempotencyConflict.new(extract_message(response), code: code, response: response)
        else
          raise InvalidRequestError.new(extract_message(response), code: code, response: response)
        end
      when 402
        raise NoStampsError.new(extract_message(response), code: extract_code(response), response: response)
      when 422
        raise FiscalValidationError.new(extract_message(response), code: extract_code(response), response: response)
      when 429
        raise RateLimitError.new(extract_message(response), code: extract_code(response), response: response)
      when 400..499
        raise InvalidRequestError.new(extract_message(response), code: extract_code(response), response: response)
      when 500..599
        raise ServerError.new(extract_message(response), code: extract_code(response), response: response)
      else
        raise APIError.new("Unexpected status #{response.status}", response: response)
      end
    end

    def parse_body(body)
      return nil if body.nil? || body.empty?
      JSON.parse(body)
    rescue JSON::ParserError
      body
    end

    def extract_message(response)
      parsed = parse_body(response.body)
      parsed.is_a?(Hash) ? (parsed['message'] || "HTTP #{response.status}") : "HTTP #{response.status}"
    rescue StandardError
      "HTTP #{response.status}"
    end

    def extract_code(response)
      parsed = parse_body(response.body)
      parsed.is_a?(Hash) ? parsed['code'] : nil
    rescue StandardError
      nil
    end

    def validate_configuration!
      raise ConfigurationError, 'api_key is required' unless config.valid?
    end
  end
end
