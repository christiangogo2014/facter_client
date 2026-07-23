# frozen_string_literal: true

require_relative 'lib/facter_client/version'

Gem::Specification.new do |spec|
  spec.name          = 'facter_client'
  spec.version       = FacterClient::VERSION
  spec.authors       = ['Christian Garcia']
  spec.email         = ['hola@masventa.mx']

  spec.summary       = 'Pure Ruby client for Facter CFDI 4.0 API (SAT Mexico)'
  spec.description   = 'Client for Facter API: stamp, validate, cancel CFDI, download XML/PDF. No Rails dependency.'
  spec.homepage      = 'https://github.com/christian.gogo2014/facter_client'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{lib,spec}/**/*', 'README.md', 'LICENSE.txt', 'Rakefile']
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'faraday', '~> 2.0'

  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'webmock', '~> 3.18'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'climate_control', '~> 1.2'
end
