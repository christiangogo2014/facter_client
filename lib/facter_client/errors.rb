# frozen_string_literal: true

module FacterClient
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class APIError < Error
    attr_reader :code, :response

    def initialize(message, code: nil, response: nil)
      super(message)
      @code     = code
      @response = response
    end
  end

  class AuthenticationError < APIError; end
  class RateLimitError < APIError; end
  class InvalidRequestError < APIError; end
  class NoStampsError < APIError; end
  class IdempotencyConflict < APIError; end
  class FiscalValidationError < APIError; end
  class NotFoundError < APIError; end
  class ServerError < APIError; end
end
