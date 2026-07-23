# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FacterClient::Configuration do
  describe 'defaults' do
    around do |example|
      ClimateControl.modify(
        'FACTER_API_KEY' => nil,
        'FACTER_ENVIRONMENT' => nil,
        'FACTER_TIMEOUT' => nil,
        'FACTER_WEBHOOK_SECRET' => nil,
        'FACTER_DEMO_URL' => nil,
        'FACTER_PRODUCTION_URL' => nil
      ) do
        example.run
      end
    end

    it 'sets environment to demo' do
      expect(subject.environment).to eq(:demo)
    end

    it 'sets timeout to 30' do
      expect(subject.timeout).to eq(30)
    end

    it 'has nil api_key when ENV not set' do
      expect(subject.api_key).to be_nil
    end

    it 'uses fallback demo URL' do
      expect(subject.demo_url).to eq('https://demo.facter.com.mx/api/ext/v1')
    end

    it 'uses fallback production URL' do
      expect(subject.production_url).to eq('https://v2.facter.com.mx/api/ext/v1')
    end
  end

  describe 'ENV var overrides' do
    around do |example|
      ClimateControl.modify(
        'FACTER_API_KEY' => 'fct_live_from_env',
        'FACTER_ENVIRONMENT' => 'production',
        'FACTER_TIMEOUT' => '60',
        'FACTER_WEBHOOK_SECRET' => 'secret123',
        'FACTER_DEMO_URL' => 'https://custom-demo.example.com/api',
        'FACTER_PRODUCTION_URL' => 'https://custom-prod.example.com/api'
      ) do
        example.run
      end
    end

    it 'reads api_key from ENV' do
      expect(subject.api_key).to eq('fct_live_from_env')
    end

    it 'reads environment from ENV' do
      expect(subject.environment).to eq(:production)
    end

    it 'reads timeout from ENV' do
      expect(subject.timeout).to eq(60)
    end

    it 'reads webhook_secret from ENV' do
      expect(subject.webhook_secret).to eq('secret123')
    end

    it 'reads custom demo URL from ENV' do
      expect(subject.demo_url).to eq('https://custom-demo.example.com/api')
    end

    it 'reads custom production URL from ENV' do
      expect(subject.production_url).to eq('https://custom-prod.example.com/api')
    end

    it 'uses custom production URL in base_url' do
      subject.environment = :production
      expect(subject.base_url).to eq('https://custom-prod.example.com/api')
    end
  end

  describe '#base_url' do
    it 'returns demo URL for :demo' do
      subject.environment = :demo
      expect(subject.base_url).to eq('https://demo.facter.com.mx/api/ext/v1')
    end

    it 'returns production URL for :production' do
      subject.environment = :production
      expect(subject.base_url).to eq('https://v2.facter.com.mx/api/ext/v1')
    end

    it 'raises on unknown environment' do
      subject.environment = :staging
      expect { subject.base_url }.to raise_error(FacterClient::ConfigurationError)
    end
  end

  describe '#valid?' do
    it 'returns false when api_key is nil' do
      expect(subject.valid?).to be(false)
    end

    it 'returns true when api_key is set' do
      subject.api_key = 'fct_live_test'
      expect(subject.valid?).to be(true)
    end
  end
end
