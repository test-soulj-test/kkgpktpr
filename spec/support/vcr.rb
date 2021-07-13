# frozen_string_literal: true

require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures'
  c.configure_rspec_metadata!
  c.default_cassette_options = { record: :new_episodes }
  c.hook_into :webmock

  # Filter all `*_TOKEN` environment variables
  ENV.each_pair do |k, v|
    next unless k.to_s.downcase.end_with?('_token')

    c.filter_sensitive_data("[#{k}]") { v }
  end
end
