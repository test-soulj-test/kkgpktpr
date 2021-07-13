# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReleaseTools::AutoDeploy::WaitForPipeline do
  let(:fake_client) { double(:client) }
  let(:project) { double('project') }

  let(:pipeline) do
    double(
      :pipeline,
      web_url: 'https://test.gitlab.com/gitlab-com/deployer/-/pipelines/123',
      status: 'running'
    )
  end

  subject(:waiter) do
    described_class.new(fake_client, project, 1)
  end

  def pipeline_stub(status)
    double(
      :pipeline,
      id: 1,
      web_url: 'https://test.gitlab.com/gitlab-com/deployer/-/pipelines/123',
      status: status
    )
  end

  def stub_metadata(version, ref)
    allow(ReleaseTools::GitlabOpsClient).to receive(:release_metadata)
      .with(version)
      .and_return(
        {
          'releases' => {
            'test-release' => {
              'ref' => ref
            }
          }
        }
      )
  end

  before do
    allow(ReleaseTools::AutoDeploy::Tag)
      .to receive(:current)
      .and_return('1.2.3')

    stub_metadata('1.2.3', '1.2.2021010203')
  end

  describe '#execute' do
    it 'returns false when a pipeline can not be found' do
      allow(fake_client).to receive(:pipeline)
        .and_return(nil)

      expect(waiter).to receive(:slack_notification).once

      expect(waiter.execute).to eq(false)
    end

    context 'when disable_deploy_wait_failure_slack_notification is set' do
      it 'does not notify on slack' do
        enable_feature(:disable_deploy_wait_failure_slack_notification)

        allow(fake_client).to receive(:pipeline).and_return(nil)

        expect(waiter).not_to receive(:slack_notification)

        expect(waiter.execute).to eq(false)
      end
    end

    it 'returns false when a pipeline is still running' do
      pipeline = pipeline_stub(described_class::WAITING_STATUSES.sample)

      expect(fake_client).to receive(:pipeline)
        .exactly(30).times
        .and_return(pipeline)

      expect(waiter).to receive(:slack_notification).once

      expect(waiter.execute).to eq(false)
    end

    it 'returns false immediately when a pipeline has failed' do
      pipeline = pipeline_stub(described_class::FAILURE_STATUSES.sample)

      expect(fake_client).to receive(:pipeline)
        .once
        .and_return(pipeline)

      expect(waiter).to receive(:slack_notification).once

      expect(waiter.execute).to eq(false)
    end

    it 'returns true on successful pipeline' do
      pipeline = pipeline_stub('success')

      expect(fake_client).to receive(:pipeline)
        .once
        .and_return(pipeline)

      expect(waiter).not_to receive(:slack_notification)

      expect(waiter.execute).to eq(true)
    end
  end
end
