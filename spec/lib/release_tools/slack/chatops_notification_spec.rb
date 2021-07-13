# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Slack::ChatopsNotification do
  include SlackWebhookHelpers

  let(:webhook_url) { 'https://slack.example.com/' }

  describe '.webhook_url' do
    it 'returns ENV value when set' do
      ClimateControl.modify(SLACK_CHATOPS_URL: webhook_url) do
        expect(described_class.webhook_url).to eq(webhook_url)
      end
    end
  end

  describe '.release_issue' do
    around do |ex|
      env = {
        CI_JOB_URL: 'ci.example.com',
        SLACK_CHATOPS_URL: webhook_url,
        TASK: 'release_issue',
      }

      ClimateControl.modify(env) { ex.run }
    end

    context 'outside of ChatOps' do
      around do |ex|
        ClimateControl.modify(TASK: nil) { ex.run }
      end

      it 'does nothing' do
        expect(described_class).not_to receive(:fire_hook)

        described_class.release_issue(spy)
      end
    end

    context 'with a new issue' do
      around do |ex|
        ClimateControl.modify(CHAT_CHANNEL: 'foo') { ex.run }
      end

      it 'posts a success message' do
        issue = double(status: :created, title: 'Title', url: 'example.com')

        expect_post(
          json: {
            text: 'The `release_issue` command at ci.example.com completed!',
            channel: 'foo',
            attachments: [{
              fallback: '',
              color: 'good',
              title: 'Title',
              title_link: 'example.com'
            }]
          }
        ).and_return(response(200))

        described_class.release_issue(issue)
      end
    end

    context 'with a pre-existing issue' do
      it 'posts a warning message' do
        issue = double(status: :persisted, title: 'Title', url: 'example.com')

        expect_post(
          json: {
            text: 'The `release_issue` command at ci.example.com completed!',
            attachments: [{
              fallback: '',
              color: 'warning',
              title: 'Title',
              title_link: 'example.com'
            }]
          }
        ).and_return(response(200))

        described_class.release_issue(issue)
      end
    end
  end

  describe '.security_merge_requests_processed' do
    around do |ex|
      ClimateControl.modify(CI_JOB_URL: 'https://test.example.com/') { ex.run }
    end

    context 'with no attachments' do
      it 'skips the message' do
        result = instance_double(ReleaseTools::Security::BatchMergerResult)

        allow(described_class)
          .to receive(:channel)
          .and_return('foo')

        allow(result)
          .to receive(:build_attachments)
          .and_return([])

        expect(described_class)
          .not_to receive(:fire_hook)

        described_class.security_merge_requests_processed(result)
      end
    end

    context 'with attachments' do
      it 'posts a message' do
        result = instance_double(ReleaseTools::Security::BatchMergerResult)
        attachments = %w[1 2 3]

        allow(described_class)
          .to receive(:channel)
          .and_return('foo')

        allow(result)
          .to receive(:build_attachments)
          .and_return(attachments)

        expect(described_class)
          .to receive(:fire_hook)
          .with(
            text: 'The `merge` command at https://test.example.com/ completed!',
            channel: 'foo',
            blocks: attachments
          )

        described_class.security_merge_requests_processed(result)
      end
    end
  end

  describe '.branch_status' do
    it 'posts a block-based message' do
      project = double(to_s: 'foo/bar')
      result = double(status: 'success', web_url: 'https://example.com', ref: 'abcdefg')

      expect(described_class)
        .to receive(:fire_hook).with(
          a_hash_including(
            blocks: [{
              type: 'section',
              fields: [{
                type: 'mrkdwn',
                text: "*foo/bar*\n:status_success: <https://example.com|abcdefg>"
              }]
            }]
          )
        )

      described_class.branch_status(project => [result])
    end
  end

  describe '.security_implementation_issues_processed' do
    it 'posts a message' do
      result = instance_double(ReleaseTools::Security::BatchMergerResult)

      attachments = {
        type: 'section',
        text:
        {
          type: 'mrkdwn',
          text: '* :information_source: Security Implementation Issues associated: 4.*'
        }
      }

      allow(described_class)
        .to receive(:channel)
        .and_return('foo')

      allow(result)
        .to receive(:build_attachments)
        .and_return([attachments])

      expect(described_class)
        .to receive(:fire_hook)
        .with(
          channel: 'foo',
          blocks: [attachments]
        )

      described_class.security_implementation_issues_processed(result)
    end
  end
end
