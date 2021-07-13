# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::StatusNote do
  let(:version) { '42.0.202005220540-7c84ccdc806.59f00bb0515' }
  let(:ci_pipeline_url) { 'https://example.com/pipeline' }
  let(:status) { double('status', fine?: true, to_issue_body: 'a collection of check results') }
  let(:release_manager) { '@a-user' }
  let(:override_status) { false }
  let(:override_reason) { 'a reason to override the status' }
  let(:services_status) { [] }

  subject(:note) do
    described_class.new(
      status: status,
      package_version: version,
      ci_pipeline_url: ci_pipeline_url,
      release_manager: release_manager,
      override_status: override_status,
      override_reason: override_reason
    ).body
  end

  it 'links the pipeline' do
    expect(note).to include("[deployer pipeline](#{ci_pipeline_url})")
  end

  it 'includes the generated report' do
    expect(note).to include(status.to_issue_body)
  end

  context 'when the pipeline url is nil' do
    let(:ci_pipeline_url) { nil }

    it 'does not link the pipeline' do
      expect(note).not_to include('this release-tools pipeline')
    end
  end

  it 'pings the release manager' do
    expect(note).to include(release_manager)
  end

  it 'includes the package version' do
    expect(note).to include("started a production deployment for package `#{version}`")
  end

  it "doesn't include the overriding reason when not override_status is false" do
    expect(note).not_to include(override_reason)
  end

  context 'when overriding the status' do
    let(:override_status) { true }

    it 'warn that the decision was overridden' do
      expect(note).to include(":warning: Status check overridden!")
    end

    it 'quotes the reason' do
      expect(note).to include(override_reason)
    end
  end
end
