# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FacterClient::Client do
  let(:client) { FacterClient::Client.new }

  describe '#initialize' do
    it 'raises ConfigurationError without api_key' do
      FacterClient.reset_configuration!
      expect { FacterClient::Client.new }.to raise_error(FacterClient::ConfigurationError)
    end

    it 'succeeds with valid config' do
      expect(client).to be_a(FacterClient::Client)
    end
  end

  describe '#get' do
    it 'makes a GET request with auth header' do
      stub = stub_request(:get, "#{DEMO_URL}/emisores")
        .with(headers: { 'Authorization' => 'Bearer fct_live_test_key_12345' })
        .to_return(status: 200, body: '{"status":"success","data":[]}', headers: { 'Content-Type' => 'application/json' })

      result = client.get('/emisores')
      expect(stub).to have_been_requested
      expect(result['status']).to eq('success')
    end
  end

  describe '#post' do
    it 'makes a POST request with idempotency key' do
      stub = stub_request(:post, "#{DEMO_URL}/cfdis")
        .with(
          headers: {
            'Authorization' => 'Bearer fct_live_test_key_12345',
            'Content-Type' => 'application/json'
          }
        )
        .to_return(
          status: 201,
          body: '{"status":"success","data":{"uuid":"test-uuid"}}',
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.post('/cfdis', body: { emisor_rfc: 'EKU9003173C9' }, idempotency_key: 'test-key-123')
      expect(stub).to have_been_requested
      expect(result['data']['uuid']).to eq('test-uuid')
    end

    it 'auto-generates idempotency key when not provided' do
      stub = stub_request(:post, "#{DEMO_URL}/cfdis")
        .with(headers: { 'Content-Type' => 'application/json' })
        .to_return(status: 201, body: '{"status":"success","data":{}}', headers: { 'Content-Type' => 'application/json' })

      client.post('/cfdis', body: {})
      expect(stub).to have_been_requested
    end

    it 'does not send idempotency key when explicitly set to false' do
      stub = stub_request(:post, "#{DEMO_URL}/cfdis/validate")
        .with { |req| !req.headers.key?('Idempotency-Key') }
        .to_return(status: 200, body: '{"status":"success","data":{"valid":true}}', headers: { 'Content-Type' => 'application/json' })

      client.post('/cfdis/validate', body: {}, idempotency_key: false)
      expect(stub).to have_been_requested
    end
  end

  describe 'error handling' do
    it 'raises AuthenticationError on 401' do
      stub_request(:get, "#{DEMO_URL}/emisores")
        .to_return(status: 401, body: '{"code":"INVALID_API_KEY","message":"Invalid API key"}')

      expect { client.get('/emisores') }.to raise_error(FacterClient::AuthenticationError)
    end

    it 'raises NoStampsError on 402' do
      stub_request(:post, "#{DEMO_URL}/cfdis")
        .to_return(status: 402, body: '{"code":"NO_STAMPS_AVAILABLE","message":"No stamps available"}')

      expect { client.post('/cfdis', body: {}) }.to raise_error(FacterClient::NoStampsError)
    end

    it 'raises IdempotencyConflict on 409 with IDEMPOTENCY_CONFLICT' do
      stub_request(:post, "#{DEMO_URL}/cfdis")
        .to_return(status: 409, body: '{"code":"IDEMPOTENCY_CONFLICT","message":"Conflict"}')

      expect { client.post('/cfdis', body: {}) }.to raise_error(FacterClient::IdempotencyConflict)
    end

    it 'raises FiscalValidationError on 422' do
      stub_request(:post, "#{DEMO_URL}/cfdis")
        .to_return(status: 422, body: '{"code":"FISCAL_VALIDATION_FAILED","message":"Validation failed"}')

      expect { client.post('/cfdis', body: {}) }.to raise_error(FacterClient::FiscalValidationError)
    end

    it 'raises RateLimitError on 429' do
      stub_request(:get, "#{DEMO_URL}/emisores")
        .to_return(status: 429, body: '{"code":"RATE_LIMITED","message":"Rate limited"}')

      expect { client.get('/emisores') }.to raise_error(FacterClient::RateLimitError)
    end

    it 'raises ServerError on 500' do
      stub_request(:get, "#{DEMO_URL}/emisores")
        .to_return(status: 500, body: '{"code":"INTERNAL_ERROR","message":"Internal error"}')

      expect { client.get('/emisores') }.to raise_error(FacterClient::ServerError)
    end

    it 'raises NotFoundError on 404' do
      stub_request(:get, "#{DEMO_URL}/cfdis/nonexistent/xml")
        .to_return(status: 404, body: '{"code":"CFDI_NOT_FOUND","message":"Not found"}')

      expect { client.get('/cfdis/nonexistent/xml') }.to raise_error(FacterClient::NotFoundError)
    end
  end

  describe '#get_raw' do
    it 'returns raw body for XML download' do
      stub_request(:get, "#{DEMO_URL}/cfdis/test-uuid/xml")
        .to_return(status: 200, body: '<xml>test</xml>')

      result = client.get_raw('/cfdis/test-uuid/xml')
      expect(result).to eq('<xml>test</xml>')
    end
  end
end
