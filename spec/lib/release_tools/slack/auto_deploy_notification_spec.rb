# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Slack::AutoDeployNotification do
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

  describe '.on_create' do
    around do |ex|
      ClimateControl.modify(AUTO_DEPLOY_NOTIFICATION_URL: webhook_url) do
        ex.run
      end
    end

    it 'posts a message with the branch name' do
      expect(described_class).to receive(:fire_hook)
        .with(a_hash_including(text: "New auto-deploy branch: `branch-name`"))

      described_class.on_create([
        double(branch: 'branch-name', project: 'gitlab-foss')
      ])
    end
  end
end
