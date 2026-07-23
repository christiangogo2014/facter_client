# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FacterClient do
  describe '.configure' do
    it 'yields configuration' do
      described_class.configure do |config|
        config.api_key = 'fct_live_test'
      end

      expect(described_class.configuration.api_key).to eq('fct_live_test')
    end
  end

  describe '.reset_configuration!' do
    it 'resets to defaults' do
      described_class.configure { |c| c.api_key = 'fct_live_test' }
      described_class.reset_configuration!

      expect(described_class.configuration.api_key).to be_nil
    end
  end

  describe 'convenience methods' do
    let(:sample_cfdi) { { 'Version' => '4.0' } }

    it '.stamp delegates to cfdis resource' do
      stub_request(:post, "#{DEMO_URL}/cfdis")
        .to_return(status: 201, body: '{"data":{"uuid":"abc"}}', headers: { 'Content-Type' => 'application/json' })

      result = described_class.stamp(emisor_rfc: 'EKU9003173C9', cfdi: sample_cfdi)
      expect(result['data']['uuid']).to eq('abc')
    end

    it '.validate delegates to cfdis resource' do
      stub_request(:post, "#{DEMO_URL}/cfdis/validate")
        .to_return(status: 200, body: '{"data":{"valid":true}}', headers: { 'Content-Type' => 'application/json' })

      result = described_class.validate(emisor_rfc: 'EKU9003173C9', cfdi: sample_cfdi)
      expect(result['data']['valid']).to be(true)
    end

    it '.cancel delegates to cfdis resource' do
      stub_request(:post, "#{DEMO_URL}/cfdis/abc/cancelacion")
        .to_return(status: 202, body: '{"status":"success"}')

      result = described_class.cancel(uuid: 'abc', motivo: '02')
      expect(result['status']).to eq('success')
    end

    it '.get_xml delegates to cfdis resource' do
      stub_request(:get, "#{DEMO_URL}/cfdis/abc/xml")
        .to_return(status: 200, body: '<xml>test</xml>')

      expect(described_class.get_xml(uuid: 'abc')).to eq('<xml>test</xml>')
    end

    it '.list_emisors delegates to emisors resource' do
      stub_request(:get, "#{DEMO_URL}/emisores")
        .to_return(status: 200, body: '{"data":[]}', headers: { 'Content-Type' => 'application/json' })

      result = described_class.list_emisors
      expect(result['data']).to eq([])
    end
  end

  describe '.verify_webhook_signature' do
    before do
      described_class.configure { |c| c.webhook_secret = 'test_secret' }
    end

    it 'returns true for valid signature' do
      payload = '{"event":"cfdi.timbrado","data":{"uuid":"abc"}}'
      digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), 'test_secret', payload)
      signature = "sha256=#{digest}"

      expect(described_class.verify_webhook_signature(payload: payload, signature: signature)).to be(true)
    end

    it 'returns false for invalid signature' do
      expect(described_class.verify_webhook_signature(payload: 'test', signature: 'sha256=invalid')).to be(false)
    end

    it 'returns false for nil signature' do
      expect(described_class.verify_webhook_signature(payload: 'test', signature: nil)).to be(false)
    end

    it 'raises ConfigurationError without webhook_secret' do
      described_class.configure { |c| c.webhook_secret = nil }

      expect {
        described_class.verify_webhook_signature(payload: 'test', signature: 'sha256=abc')
      }.to raise_error(FacterClient::ConfigurationError)
    end
  end
end
