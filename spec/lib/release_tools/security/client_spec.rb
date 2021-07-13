# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Security::Client do
  let(:client) { described_class.new }

  it_behaves_like 'security_client #open_security_merge_requests'
  it_behaves_like 'security_client #release_tools_bot'
  it_behaves_like 'security_client #latest_merge_request_pipeline'
  it_behaves_like 'security_client #method_missing'
  it_behaves_like 'security_client #respond_to?'
end
