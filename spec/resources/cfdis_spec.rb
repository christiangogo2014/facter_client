# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FacterClient::Resources::Cfdis do
  let(:client) { FacterClient::Client.new }
  let(:cfdis) { described_class.new(client) }

  let(:sample_cfdi) do
    {
      'Version' => '4.0',
      'Serie' => 'A',
      'Folio' => '123',
      'FormaPago' => '01',
      'MetodoPago' => 'PUE',
      'SubTotal' => '1000.00',
      'Moneda' => 'MXN',
      'Total' => '1160.00',
      'TipoDeComprobante' => 'I',
      'Exportacion' => '01',
      'LugarExpedicion' => '64000',
      'Emisor' => { 'Rfc' => 'EKU9003173C9', 'Nombre' => 'TEST', 'RegimenFiscal' => '601' },
      'Receptor' => { 'Rfc' => 'XAXX010101000', 'Nombre' => 'PUBLICO', 'DomicilioFiscalReceptor' => '64000', 'RegimenFiscalReceptor' => '616', 'UsoCFDI' => 'S01' },
      'Conceptos' => [],
      'Impuestos' => {}
    }
  end

  describe '#stamp' do
    it 'POSTs to /cfdis with correct payload' do
      stub = stub_request(:post, "#{DEMO_URL}/cfdis")
        .with(body: hash_including(emisor_rfc: 'EKU9003173C9'))
        .to_return(
          status: 201,
          body: '{"status":"success","data":{"uuid":"abc-123","total":"1160.00","timbres":{"consumidos":1,"saldo_restante":4987}}}',
          headers: { 'Content-Type' => 'application/json' }
        )

      result = cfdis.stamp(emisor_rfc: 'EKU9003173C9', cfdi: sample_cfdi, external_ref: 'REF-001')
      expect(stub).to have_been_requested
      expect(result['data']['uuid']).to eq('abc-123')
    end

    it 'accepts custom idempotency key' do
      stub = stub_request(:post, "#{DEMO_URL}/cfdis")
        .with(headers: { 'Idempotency-Key' => 'custom-key-456' })
        .to_return(status: 201, body: '{"status":"success","data":{"uuid":"abc"}}', headers: { 'Content-Type' => 'application/json' })

      cfdis.stamp(emisor_rfc: 'EKU9003173C9', cfdi: sample_cfdi, idempotency_key: 'custom-key-456')
      expect(stub).to have_been_requested
    end
  end

  describe '#validate' do
    it 'POSTs to /cfdis/validate without idempotency key' do
      stub = stub_request(:post, "#{DEMO_URL}/cfdis/validate")
        .to_return(
          status: 200,
          body: '{"status":"success","data":{"valid":true,"errors":[],"warnings":[]}}',
          headers: { 'Content-Type' => 'application/json' }
        )

      result = cfdis.validate(emisor_rfc: 'EKU9003173C9', cfdi: sample_cfdi)
      expect(stub).to have_been_requested
      expect(result['data']['valid']).to be(true)
    end
  end

  describe '#cancel' do
    it 'POSTs to /cfdis/{uuid}/cancelacion' do
      stub = stub_request(:post, "#{DEMO_URL}/cfdis/abc-123/cancelacion")
        .with(body: hash_including(motivo: '02'))
        .to_return(status: 202, body: '{"status":"success","message":"Cancelacion solicitada"}')

      result = cfdis.cancel(uuid: 'abc-123', motivo: '02')
      expect(stub).to have_been_requested
      expect(result['status']).to eq('success')
    end

    it 'includes folio_sustitucion_uuid when provided' do
      stub = stub_request(:post, "#{DEMO_URL}/cfdis/abc-123/cancelacion")
        .with(body: hash_including(motivo: '01', folio_sustitucion_uuid: 'new-uuid'))
        .to_return(status: 202, body: '{"status":"success"}')

      cfdis.cancel(uuid: 'abc-123', motivo: '01', folio_sustitucion_uuid: 'new-uuid')
      expect(stub).to have_been_requested
    end
  end

  describe '#cancelation_status' do
    it 'GETs /cfdis/{uuid}/cancelacion' do
      stub = stub_request(:get, "#{DEMO_URL}/cfdis/abc-123/cancelacion")
        .to_return(status: 200, body: '{"data":{"cancel_status":"CANCELADO"}}')

      result = cfdis.cancelation_status(uuid: 'abc-123')
      expect(stub).to have_been_requested
      expect(result['data']['cancel_status']).to eq('CANCELADO')
    end
  end

  describe '#get_xml' do
    it 'returns raw XML' do
      stub_request(:get, "#{DEMO_URL}/cfdis/abc-123/xml")
        .to_return(status: 200, body: '<cfdi:Comprobante>...</cfdi:Comprobante>')

      result = cfdis.get_xml(uuid: 'abc-123')
      expect(result).to include('<cfdi:Comprobante')
    end
  end

  describe '#get_pdf' do
    it 'returns raw PDF binary' do
      stub_request(:get, "#{DEMO_URL}/cfdis/abc-123/pdf")
        .to_return(status: 200, body: '%PDF-1.4 fake pdf content')

      result = cfdis.get_pdf(uuid: 'abc-123')
      expect(result).to include('%PDF')
    end
  end
end
