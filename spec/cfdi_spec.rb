# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FacterClient::CFDI do
  let(:emisor) do
    {
      rfc: 'EKU9003173C9',
      nombre: 'ESCUELA KEMPER URGATE',
      regimen_fiscal: '601',
      codigo_postal: '64000'
    }
  end

  let(:receptor) do
    {
      rfc: 'XAXX010101000',
      nombre: 'PUBLICO EN GENERAL',
      domicilio_fiscal_receptor: '64000',
      regimen_fiscal_receptor: '616',
      uso_cfdi: 'S01'
    }
  end

  let(:conceptos) do
    [
      {
        clave_prod_serv: '01010101',
        no_identificacion: 'SKU-01',
        cantidad: '1',
        clave_unidad: 'H87',
        unidad: 'Pieza',
        descripcion: 'Producto de prueba',
        valor_unitario: '1000.00',
        objeto_imp: '02',
        impuestos: {
          'Traslados' => [
            {
              'Base' => '1000.00',
              'Impuesto' => '002',
              'TipoFactor' => 'Tasa',
              'TasaOCuota' => '0.160000',
              'Importe' => '160.00'
            }
          ],
          'Retenciones' => []
        }
      }
    ]
  end

  let(:exempt_conceptos) do
    [
      {
        clave_prod_serv: '01010101',
        no_identificacion: 'SKU-01',
        cantidad: '1',
        clave_unidad: 'H87',
        unidad: 'Pieza',
        descripcion: 'Producto de prueba',
        valor_unitario: '1000.00'
      }
    ]
  end

  describe '.build_income' do
    it 'builds a valid CFDI 4.0 hash' do
      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: conceptos,
        folio: '123'
      )

      expect(cfdi['Version']).to eq('4.0')
      expect(cfdi['TipoDeComprobante']).to eq('I')
      expect(cfdi['Serie']).to eq('A')
      expect(cfdi['Folio']).to eq('123')
      expect(cfdi['Moneda']).to eq('MXN')
      expect(cfdi['MetodoPago']).to eq('PUE')
    end

    it 'calculates subtotal from conceptos' do
      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: conceptos
      )

      expect(cfdi['SubTotal']).to eq('1000.00')
    end

    it 'sums user-provided traslados and calculates total' do
      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: conceptos
      )

      expect(cfdi['Total']).to eq('1160.00')
      expect(cfdi['Impuestos']['TotalImpuestosTrasladados']).to eq('160.00')
    end

    it 'passes through user-provided concepto impuestos unchanged' do
      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: conceptos
      )

      concepto = cfdi['Conceptos'].first
      expect(concepto['Importe']).to eq('1000.00')
      expect(concepto['Impuestos']['Traslados'].first['Base']).to eq('1000.00')
      expect(concepto['Impuestos']['Traslados'].first['Importe']).to eq('160.00')
      expect(concepto['Impuestos']['Traslados'].first['Impuesto']).to eq('002')
      expect(concepto['Impuestos']['Traslados'].first['TasaOCuota']).to eq('0.160000')
    end

    it 'normalizes emisor and receptor to string keys' do
      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: conceptos
      )

      expect(cfdi['Emisor']['Rfc']).to eq('EKU9003173C9')
      expect(cfdi['Emisor']['Nombre']).to eq('ESCUELA KEMPER URGATE')
      expect(cfdi['Emisor']['RegimenFiscal']).to eq('601')

      expect(cfdi['Receptor']['Rfc']).to eq('XAXX010101000')
      expect(cfdi['Receptor']['UsoCFDI']).to eq('S01')
    end

    it 'uses emisor codigo_postal as lugar_expedicion by default' do
      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: conceptos
      )

      expect(cfdi['LugarExpedicion']).to eq('64000')
    end

    it 'handles multiple conceptos with user-provided taxes' do
      multi_conceptos = [
        {
          clave_prod_serv: '01010101',
          cantidad: '2',
          descripcion: 'Item A',
          valor_unitario: '500.00',
          objeto_imp: '02',
          impuestos: {
            'Traslados' => [
              { 'Base' => '1000.00', 'Impuesto' => '002', 'TipoFactor' => 'Tasa', 'TasaOCuota' => '0.160000', 'Importe' => '160.00' }
            ],
            'Retenciones' => []
          }
        },
        {
          clave_prod_serv: '01010102',
          cantidad: '1',
          descripcion: 'Item B',
          valor_unitario: '1000.00',
          objeto_imp: '02',
          impuestos: {
            'Traslados' => [
              { 'Base' => '1000.00', 'Impuesto' => '002', 'TipoFactor' => 'Tasa', 'TasaOCuota' => '0.160000', 'Importe' => '160.00' }
            ],
            'Retenciones' => []
          }
        }
      ]

      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: multi_conceptos
      )

      expect(cfdi['SubTotal']).to eq('2000.00')
      expect(cfdi['Total']).to eq('2320.00')
      expect(cfdi['Impuestos']['TotalImpuestosTrasladados']).to eq('320.00')
      expect(cfdi['Conceptos'].size).to eq(2)
    end

    it 'defaults ObjetoImp to 01 (no IVA) when not specified' do
      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: exempt_conceptos
      )

      concepto = cfdi['Conceptos'].first
      expect(concepto['ObjetoImp']).to eq('01')
      expect(concepto['Impuestos']).to be_nil
      expect(cfdi['SubTotal']).to eq('1000.00')
      expect(cfdi['Total']).to eq('1000.00')
      expect(cfdi['Impuestos']).to be_nil
    end

    it 'passes through impuestos hash when objeto_imp is 02' do
      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: conceptos
      )

      concepto = cfdi['Conceptos'].first
      expect(concepto['ObjetoImp']).to eq('02')
      expect(concepto['Impuestos']).to be_a(Hash)
      expect(cfdi['Total']).to eq('1160.00')
    end

    it 'skips IVA for exempt conceptos (objeto_imp 01)' do
      exempt = [
        {
          clave_prod_serv: '80131500',
          cantidad: '1',
          descripcion: 'Arrendamiento de inmueble',
          valor_unitario: '10000.00',
          objeto_imp: '01'
        }
      ]

      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: exempt
      )

      concepto = cfdi['Conceptos'].first
      expect(concepto['ObjetoImp']).to eq('01')
      expect(concepto['Impuestos']).to be_nil
      expect(cfdi['SubTotal']).to eq('10000.00')
      expect(cfdi['Total']).to eq('10000.00')
      expect(cfdi['Impuestos']).to be_nil
    end

    it 'handles mixed taxable and exempt conceptos' do
      mixed_conceptos = [
        {
          clave_prod_serv: '50111500',
          cantidad: '1',
          descripcion: 'Servicio de publicidad',
          valor_unitario: '5000.00',
          objeto_imp: '02',
          impuestos: {
            'Traslados' => [
              { 'Base' => '5000.00', 'Impuesto' => '002', 'TipoFactor' => 'Tasa', 'TasaOCuota' => '0.160000', 'Importe' => '800.00' }
            ],
            'Retenciones' => []
          }
        },
        {
          clave_prod_serv: '80131500',
          cantidad: '1',
          descripcion: 'Arrendamiento',
          valor_unitario: '10000.00',
          objeto_imp: '01'
        }
      ]

      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: mixed_conceptos
      )

      expect(cfdi['SubTotal']).to eq('15000.00')
      expect(cfdi['Total']).to eq('15800.00')
      expect(cfdi['Impuestos']['TotalImpuestosTrasladados']).to eq('800.00')

      taxable = cfdi['Conceptos'].first
      exempt = cfdi['Conceptos'].last
      expect(taxable['Impuestos']).to be_a(Hash)
      expect(exempt['Impuestos']).to be_nil

      expect(cfdi['Impuestos']['Traslados'].size).to eq(1)
    end

    it 'handles retenciones (ISR, IVA retention)' do
      conceptos_with_retencion = [
        {
          clave_prod_serv: '43232408',
          cantidad: '1',
          descripcion: 'Software development services',
          valor_unitario: '10000.00',
          objeto_imp: '02',
          impuestos: {
            'Traslados' => [
              { 'Base' => '10000.00', 'Impuesto' => '002', 'TipoFactor' => 'Tasa', 'TasaOCuota' => '0.160000', 'Importe' => '1600.00' }
            ],
            'Retenciones' => [
              { 'Base' => '10000.00', 'Impuesto' => '001', 'TipoFactor' => 'Tasa', 'TasaOCuota' => '0.100000', 'Importe' => '1000.00' }
            ]
          }
        }
      ]

      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: conceptos_with_retencion
      )

      expect(cfdi['SubTotal']).to eq('10000.00')
      expect(cfdi['Impuestos']['TotalImpuestosTrasladados']).to eq('1600.00')
      expect(cfdi['Impuestos']['TotalImpuestosRetenidos']).to eq('1000.00')
      expect(cfdi['Total']).to eq('10600.00') # 10000 + 1600 - 1000
    end

    it 'handles IVA 0% (tasa cero)' do
      conceptos_iva_cero = [
        {
          clave_prod_serv: '01010101',
          cantidad: '1',
          descripcion: 'Producto exento de IVA (tasa 0%)',
          valor_unitario: '5000.00',
          objeto_imp: '02',
          impuestos: {
            'Traslados' => [
              { 'Base' => '5000.00', 'Impuesto' => '002', 'TipoFactor' => 'Tasa', 'TasaOCuota' => '0.000000', 'Importe' => '0.00' }
            ],
            'Retenciones' => []
          }
        }
      ]

      cfdi = described_class.build_income(
        emisor: emisor,
        receptor: receptor,
        conceptos: conceptos_iva_cero
      )

      expect(cfdi['SubTotal']).to eq('5000.00')
      expect(cfdi['Impuestos']['TotalImpuestosTrasladados']).to eq('0.00')
      expect(cfdi['Total']).to eq('5000.00')
    end
  end

  describe '.build_income_simple' do
    it 'builds CFDI with flat parameters' do
      cfdi = described_class.build_income_simple(
        emisor_rfc: 'EKU9003173C9',
        emisor_nombre: 'ESCUELA KEMPER URGATE',
        emisor_regimen_fiscal: '601',
        emisor_codigo_postal: '64000',
        receptor_rfc: 'XAXX010101000',
        receptor_nombre: 'PUBLICO EN GENERAL',
        receptor_domicilio_fiscal: '64000',
        receptor_regimen_fiscal_receptor: '616',
        receptor_uso_cfdi: 'S01',
        conceptos: conceptos,
        folio: '456'
      )

      expect(cfdi['Version']).to eq('4.0')
      expect(cfdi['Folio']).to eq('456')
      expect(cfdi['Total']).to eq('1160.00') # 1000 + 160 IVA (user-provided)
    end
  end
end
