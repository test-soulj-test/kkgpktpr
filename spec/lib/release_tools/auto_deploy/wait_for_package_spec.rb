# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReleaseTools::AutoDeploy::WaitForPackage do
  let!(:fake_client) { stub_const('ReleaseTools::GitlabDevClient', spy) }

  def pipeline_stub(status)
    double('Pipeline', id: 1, web_url: 'example.com', status: status)
  end

  before do
    fake_instance = double(:instance)

    allow(ReleaseTools::AutoDeploy::Tag)
      .to receive(:new)
      .and_return(fake_instance)

    allow(fake_instance)
      .to receive(:component_ref)
      .with(component: 'test-release')
      .and_return('1.2.2021010203')
  end

  describe '#execute' do
    let(:project) { double('Project') }

    it 'returns false when a pipeline is missing' do
      waiter = described_class.new(project, 'test-release')

      expect(fake_client).to receive(:pipelines)
        .with(project, ref: '1.2.2021010203', order_by: 'id', sort: 'desc')
        .exactly(10).times
        .and_return([])

      expect(waiter).not_to receive(:check_status!)
      expect(waiter).to receive(:slack_notification).once

      expect(waiter.execute).to eq(false)
    end

    it 'returns false when a pipeline is still running' do
      pipeline = pipeline_stub(described_class::WAITING_STATUSES.sample)
      waiter = described_class.new(project, 'test-release')

      expect(fake_client).to receive(:pipelines)
        .and_return([pipeline])

      expect(fake_client).to receive(:pipeline)
        .exactly(30).times
        .and_return(pipeline)

      expect(waiter).to receive(:slack_notification).once

      expect(waiter.execute).to eq(false)
    end

    it 'returns false immediately when a pipeline has failed' do
      pipeline = pipeline_stub(described_class::FAILURE_STATUSES.sample)
      waiter = described_class.new(project, 'test-release')

      expect(fake_client).to receive(:pipelines)
        .and_return([pipeline])

      expect(fake_client).to receive(:pipeline)
        .once
        .and_return(pipeline)

      expect(waiter).to receive(:slack_notification).once

      expect(waiter.execute).to eq(false)
    end

    it 'returns true on successful pipeline' do
      pipeline = pipeline_stub('success')
      waiter = described_class.new(project, 'test-release')

      expect(fake_client).to receive(:pipelines)
        .and_return([pipeline])

      expect(fake_client).to receive(:pipeline)
        .once
        .and_return(pipeline)

      expect(waiter).not_to receive(:slack_notification)

      expect(waiter.execute).to eq(true)
    end
  end
end
