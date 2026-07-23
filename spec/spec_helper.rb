# frozen_string_literal: true

require 'facter_client'
require 'webmock/rspec'
require 'climate_control'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
end

DEMO_URL = 'https://demo.facter.com.mx/api/ext/v1'
PRODUCTION_URL = 'https://v2.facter.com.mx/api/ext/v1'

def reset_facter_client!
  FacterClient.reset_configuration!
  FacterClient.configure do |c|
    c.api_key     = 'fct_live_test_key_12345'
    c.environment = :demo
    c.timeout     = 10
  end
end

RSpec.configure do |config|
  config.before(:each) do
    reset_facter_client!
  end
end
