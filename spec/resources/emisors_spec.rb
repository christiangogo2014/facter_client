# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FacterClient::Resources::Emisors do
  let(:client) { FacterClient::Client.new }
  let(:emisors) { described_class.new(client) }

  describe '#list' do
    it 'GETs /emisores' do
      stub = stub_request(:get, "#{DEMO_URL}/emisores")
        .to_return(
          status: 200,
          body: '{"status":"success","data":[{"rfc":"EKU9003173C9","is_principal":true}]}',
          headers: { 'Content-Type' => 'application/json' }
        )

      result = emisors.list
      expect(stub).to have_been_requested
      expect(result['data'].first['rfc']).to eq('EKU9003173C9')
    end
  end

  describe '#get' do
    it 'GETs /emisores/{rfc}' do
      stub = stub_request(:get, "#{DEMO_URL}/emisores/EKU9003173C9")
        .to_return(
          status: 200,
          body: '{"status":"success","data":{"rfc":"EKU9003173C9","razon_social":"ESCUELA KEMPER URGATE"}}',
          headers: { 'Content-Type' => 'application/json' }
        )

      result = emisors.get(rfc: 'EKU9003173C9')
      expect(stub).to have_been_requested
      expect(result['data']['razon_social']).to eq('ESCUELA KEMPER URGATE')
    end
  end
end
