# frozen_string_literal: true

require 'bigdecimal'

module FacterClient
  module CFDI
    IVA_RATE = '0.160000'
    IVA_IMPUESTO = '002'
    IVA_TIPO_FACTOR = 'Tasa'

    module_function

    def build_income(
      emisor:,
      receptor:,
      conceptos:,
      serie: 'A',
      folio: nil,
      forma_pago: '01',
      metodo_pago: 'PUE',
      condiciones_de_pago: nil,
      moneda: 'MXN',
      exportacion: '01',
      lugar_expedicion: nil,
      descuento: nil,
      tipo_cambio: nil,
      cfdi_relacionados: nil,
      complemento: nil,
      informacion_global: nil
    )
      lugar_expedicion ||= emisor[:codigo_postal] || emisor['codigo_postal']

      normalized_conceptos = conceptos.map { |c| normalize_concepto(c) }
      subtotal = calculate_subtotal(normalized_conceptos)
      total_impuestos = calculate_total_impuestos(normalized_conceptos)
      total = subtotal - (descuento ? BigDecimal(descuento.to_s) : 0) + total_impuestos

      {
        'Version' => '4.0',
        'Serie' => serie,
        'Folio' => folio,
        'FormaPago' => forma_pago,
        'MetodoPago' => metodo_pago,
        'CondicionesDePago' => condiciones_de_pago,
        'SubTotal' => format_money(subtotal),
        'Descuento' => descuento ? format_money(BigDecimal(descuento.to_s)) : nil,
        'Moneda' => moneda,
        'TipoCambio' => tipo_cambio,
        'Total' => format_money(total),
        'TipoDeComprobante' => 'I',
        'Exportacion' => exportacion,
        'LugarExpedicion' => lugar_expedicion,
        'Emisor' => normalize_emisor(emisor),
        'Receptor' => normalize_receptor(receptor),
        'Conceptos' => normalized_conceptos.map { |c| concepto_to_hash(c) },
        'Impuestos' => build_impuestos(normalized_conceptos, total_impuestos),
        'CfdiRelacionados' => cfdi_relacionados,
        'Complemento' => complemento,
        'InformacionGlobal' => informacion_global
      }
    end

    def build_income_simple(
      emisor_rfc:,
      emisor_nombre:,
      emisor_regimen_fiscal:,
      emisor_codigo_postal:,
      receptor_rfc:,
      receptor_nombre:,
      receptor_domicilio_fiscal:,
      receptor_regimen_fiscal_receptor:,
      receptor_uso_cfdi:,
      conceptos:,
      serie: 'A',
      folio: nil,
      forma_pago: '01',
      metodo_pago: 'PUE'
    )
      build_income(
        emisor: {
          rfc: emisor_rfc,
          nombre: emisor_nombre,
          regimen_fiscal: emisor_regimen_fiscal,
          codigo_postal: emisor_codigo_postal
        },
        receptor: {
          rfc: receptor_rfc,
          nombre: receptor_nombre,
          domicilio_fiscal_receptor: receptor_domicilio_fiscal,
          regimen_fiscal_receptor: receptor_regimen_fiscal_receptor,
          uso_cfdi: receptor_uso_cfdi
        },
        conceptos: conceptos,
        serie: serie,
        folio: folio,
        forma_pago: forma_pago,
        metodo_pago: metodo_pago
      )
    end

    class << self
      private

      def normalize_concepto(c)
        hash = c.transform_keys(&:to_sym)

        valor_unitario = BigDecimal(hash[:valor_unitario].to_s)
        cantidad = BigDecimal(hash[:cantidad].to_s)
        importe = valor_unitario * cantidad
        objeto_imp = hash[:objeto_imp] || hash[:ObjetoImp] || '01'

        {
          clave_prod_serv: hash[:clave_prod_serv] || hash[:ClaveProdServ],
          no_identificacion: hash[:no_identificacion] || hash[:NoIdentificacion],
          cantidad: format_cantidad(cantidad),
          clave_unidad: hash[:clave_unidad] || hash[:ClaveUnidad] || 'H87',
          unidad: hash[:unidad] || hash[:Unidad] || 'Pieza',
          descripcion: hash[:descripcion] || hash[:Descripcion],
          valor_unitario: format_money(valor_unitario),
          importe: format_money(importe),
          descuento: hash[:descuento] ? format_money(BigDecimal(hash[:descuento].to_s)) : nil,
          objeto_imp: objeto_imp,
          impuestos: objeto_imp == '02' ? build_concepto_impuestos(importe) : nil
        }
      end

      def concepto_to_hash(c)
        hash = {
          'ClaveProdServ' => c[:clave_prod_serv],
          'NoIdentificacion' => c[:no_identificacion],
          'Cantidad' => c[:cantidad],
          'ClaveUnidad' => c[:clave_unidad],
          'Unidad' => c[:unidad],
          'Descripcion' => c[:descripcion],
          'ValorUnitario' => c[:valor_unitario],
          'Importe' => c[:importe],
          'Descuento' => c[:descuento],
          'ObjetoImp' => c[:objeto_imp]
        }
        hash['Impuestos'] = c[:impuestos] if c[:impuestos]
        hash
      end

      def build_concepto_impuestos(base)
        iva_importe = base * BigDecimal(IVA_RATE)

        {
          'Traslados' => [
            {
              'Base' => format_money(base),
              'Impuesto' => IVA_IMPUESTO,
              'TipoFactor' => IVA_TIPO_FACTOR,
              'TasaOCuota' => IVA_RATE,
              'Importe' => format_money(iva_importe)
            }
          ],
          'Retenciones' => []
        }
      end

      def build_impuestos(conceptos, total_impuestos)
        taxable = conceptos.select { |c| c[:impuestos] }
        return nil if taxable.empty?

        traslados = taxable.map do |c|
          c[:impuestos]['Traslados'].first
        end

        {
          'TotalImpuestosTrasladados' => format_money(total_impuestos),
          'Traslados' => traslados
        }
      end

      def calculate_subtotal(conceptos)
        conceptos.sum { |c| BigDecimal(c[:importe]) }
      end

      def calculate_total_impuestos(conceptos)
        conceptos.sum do |c|
          next 0 unless c[:impuestos]
          c[:impuestos]['Traslados'].sum { |t| BigDecimal(t['Importe']) }
        end
      end

      def normalize_emisor(emisor)
        e = emisor.transform_keys(&:to_sym)
        {
          'Rfc' => e[:rfc],
          'Nombre' => e[:nombre],
          'RegimenFiscal' => e[:regimen_fiscal]
        }
      end

      def normalize_receptor(receptor)
        r = receptor.transform_keys(&:to_sym)
        {
          'Rfc' => r[:rfc],
          'Nombre' => r[:nombre],
          'DomicilioFiscalReceptor' => r[:domicilio_fiscal_receptor],
          'RegimenFiscalReceptor' => r[:regimen_fiscal_receptor],
          'UsoCFDI' => r[:uso_cfdi]
        }
      end

      def format_money(value)
        format('%.2f', value)
      end

      def format_cantidad(value)
        format('%.6f', value)
      end
    end
  end
end
