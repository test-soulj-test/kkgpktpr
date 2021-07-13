# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::DeploymentCheckForeword do
  let(:deploy_package) { '13.1.202005220540-7c84ccdc806.59f00bb0515' }
  let(:package_version) { ReleaseTools::Version.new(deploy_package) }
  let(:deployment_step) { 'gprd-cny-migrations' }
  let(:job_url) { 'http://example.com' }

  describe '#to_slack_block' do
    subject(:message) do
      described_class.new(package_version, deployment_step, job_url)
        .to_slack_block.dig(:text, :text)
    end

    it 'mentions the deployment step reached' do
      expect(message).to include(deployment_step)
    end

    it 'refers to the package version' do
      expect(message).to include(package_version)
    end

    it 'links to the job_url' do
      expect(message).to include("<#{job_url}|#{deployment_step}>")
    end
  end
end
