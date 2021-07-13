# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Slack::MergeTrainNotification do
  include SlackWebhookHelpers

  let(:webhook_url) { 'https://slack.example.com/' }

  describe '.webhook_url' do
    it 'is required' do
      ClimateControl.modify(AUTO_DEPLOY_NOTIFICATION_URL: nil) do
        expect { described_class.webhook_url }.to raise_error(KeyError)
      end
    end

    it 'returns ENV value when set' do
      ClimateControl.modify(AUTO_DEPLOY_NOTIFICATION_URL: webhook_url) do
        expect(described_class.webhook_url).to eq(webhook_url)
      end
    end
  end

  describe '.toggled' do
    around do |ex|
      ClimateControl.modify(AUTO_DEPLOY_NOTIFICATION_URL: webhook_url) do
        ex.run
      end
    end

    it 'posts a message when the schedule is toggled on' do
      schedule = double(active: true, description: 'My task')

      expect(described_class).to receive(:fire_hook) do |args|
        expect(args[:text]).to eq('Merge train toggled')
        expect(args[:blocks][0][:text][:text]).to eq(
          ":train: The *My task* merge train task has been activated due to a branch divergence."
        )
      end

      described_class.toggled(schedule)
    end

    it 'posts a message when the schedule is toggled off' do
      schedule = double(active: false, description: 'My task')

      expect(described_class).to receive(:fire_hook) do |args|
        expect(args[:text]).to eq('Merge train toggled')
        expect(args[:blocks][0][:text][:text]).to eq(
          ":train: The *My task* merge train task has been deactivated because it's no longer necessary."
        )
      end

      described_class.toggled(schedule)
    end
  end
end
