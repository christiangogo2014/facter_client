# FacterClient

Pure Ruby client for the [Facter](https://v2.facter.com.mx) CFDI 4.0 API (SAT Mexico). Stamp, validate, cancel, and download CFDI invoices. No Rails dependency.

## Installation

Add to your Gemfile:

```ruby
gem 'facter_client', git: 'https://github.com/christiangogo2014/facter_client'
```

## Configuration

```ruby
FacterClient.configure do |config|
  config.api_key        = ENV['FACTER_API_KEY']        # fct_live_xxx
  config.environment    = (ENV['FACTER_ENVIRONMENT'] || 'demo').to_sym  # :demo or :production
  config.timeout        = 30
  config.webhook_secret = ENV['FACTER_WEBHOOK_SECRET'] # optional, for webhook verification
end
```

### Environments

- `:demo` → `https://demo.facter.com.mx/api/ext/v1`
- `:production` → `https://v2.facter.com.mx/api/ext/v1`

## Usage

### Stamp a CFDI (Ingreso)

```ruby
cfdi = FacterClient::CFDI.build_income_simple(
  emisor_rfc: 'EKU9003173C9',
  emisor_nombre: 'ESCUELA KEMPER URGATE',
  emisor_regimen_fiscal: '601',
  emisor_codigo_postal: '64000',
  receptor_rfc: 'XAXX010101000',
  receptor_nombre: 'PUBLICO EN GENERAL',
  receptor_domicilio_fiscal: '64000',
  receptor_regimen_fiscal_receptor: '616',
  receptor_uso_cfdi: 'S01',
  conceptos: [
    { clave_prod_serv: '01010101', cantidad: '1', descripcion: 'Servicio de publicidad', valor_unitario: '1000.00' }
  ],
  folio: '123'
)

result = FacterClient.stamp(emisor_rfc: 'EKU9003173C9', cfdi: cfdi, external_ref: 'REF-001')
# => {"status"=>"success", "data"=>{"uuid"=>"abc-123", "total"=>"1160.00", "timbres"=>{"consumidos"=>1, "saldo_restante"=>4987}}}
```

### Validate without stamping (dry-run)

```ruby
result = FacterClient.validate(emisor_rfc: 'EKU9003173C9', cfdi: cfdi)
# => {"data"=>{"valid"=>true, "errors"=>[], "warnings"=>[]}}
```

### Cancel a CFDI

```ruby
result = FacterClient.cancel(uuid: 'abc-123', motivo: '02')
# motivo '01' requires folio_sustitucion_uuid
```

### Check cancellation status

```ruby
result = FacterClient.cancelation_status(uuid: 'abc-123')
# => {"data"=>{"cancel_status"=>"CANCELADO"}}
```

### Download XML and PDF

```ruby
xml = FacterClient.get_xml(uuid: 'abc-123')   # => raw XML string
pdf = FacterClient.get_pdf(uuid: 'abc-123')   # => raw PDF binary
```

### List emisores

```ruby
result = FacterClient.list_emisors
# => {"data"=>[{"rfc"=>"EKU9003173C9", "is_principal"=>true}]}
```

### Webhook signature verification

```ruby
verified = FacterClient.verify_webhook_signature(payload: raw_body, signature: request.headers['X-Facter-Signature'])
# => true/false
```

## CFDI Builder

The `FacterClient::CFDI` module helps construct valid CFDI 4.0 hashes:

- `build_income` — full control with hash parameters
- `build_income_simple` — flat parameters for convenience

Both auto-calculate:
- SubTotal from conceptos
- IVA 16% traslados per concepto
- Total (SubTotal - Descuento + Impuestos)
- TotalImpuestosTrasladados

## Error Handling

| Error Class | HTTP Status | Facter Code |
|---|---|---|
| `AuthenticationError` | 401, 403 | `INVALID_API_KEY` |
| `NoStampsError` | 402 | `NO_STAMPS_AVAILABLE` |
| `IdempotencyConflict` | 409 | `IDEMPOTENCY_CONFLICT` / `IDEMPOTENCY_IN_FLIGHT` |
| `FiscalValidationError` | 422 | `FISCAL_VALIDATION_FAILED` |
| `RateLimitError` | 429 | `RATE_LIMITED` |
| `NotFoundError` | 404 | `CFDI_NOT_FOUND` |
| `ServerError` | 500+ | `INTERNAL_ERROR` |
| `InvalidRequestError` | other 4xx | various |

All API errors expose `.code` (Facter's machine-readable code) and `.response` (the Faraday response object).

## Idempotency

All mutating requests automatically include an `Idempotency-Key` header (auto-generated UUID). You can override:

```ruby
FacterClient.stamp(emisor_rfc: '...', cfdi: cfdi, idempotency_key: 'your-custom-key')
```

The `validate` endpoint does not send an idempotency key (per Facter API spec).

## Testing

```bash
bundle exec rspec
```

51 specs, all passing. Uses WebMock for HTTP stubbing.
