# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::DeploymentCheckReport do
  let(:gitlab_ops_client) { spy('ReleaseTools::GitlabOpsClient') }
  let(:deployment_step) { 'gprd-migrations 50%' }
  let(:deployment_file) { described_class::DEPLOYMENT_MESSAGE_TS }

  let(:foreword) do
    double(
      :foreword,
      header: 'baz',
      to_slack_block: {
        type: 'section', text: { type: 'mrkdwn', text: 'foo' }
      }
    )
  end

  let(:status) do
    double(:status, to_slack_blocks: [])
  end

  let(:blocks) do
    [foreword.to_slack_block] + status.to_slack_blocks
  end

  subject(:deployment_check_report) do
    described_class.new(deployment_step, foreword, status)
  end

  describe '#execute' do
    context 'when the notification is sent for the first time' do
      let(:response) do
        {
          'ok' => true,
          'channel' => 'foo',
          'ts' => '123456',
          'message' => {
            'type' => 'message',
            'subtype' => 'bot_message',
            'text' => "deployment reached 100% at #{deployment_step}",
            'ts' => '123456',
            'username' => 'bot',
            'bot_id' => 'bar'
          }
        }
      end

      before do
        allow(ReleaseTools::Slack::Message)
          .to receive(:post)
          .and_return(response)

        stub_const('ReleaseTools::GitlabOpsClient', gitlab_ops_client)
      end

      after do
        FileUtils.rm_r(deployment_file) if File.exist?(deployment_file)
      end

      it 'sends a message with all the details to the slack channel' do
        expect(foreword)
          .to receive(:to_slack_block)

        expect(status)
          .to receive(:to_slack_blocks)

        expect(ReleaseTools::Slack::Message)
          .to receive(:post)
          .with(
            channel: ReleaseTools::Slack::F_UPCOMING_RELEASE,
            message: foreword.header,
            blocks: blocks,
            thread_ts: nil
          )

        without_dry_run do
          deployment_check_report.execute
        end
      end

      it 'writes down the Slack message ts' do
        expect(File)
          .to receive(:write)
          .with(deployment_file, response['ts'])

        without_dry_run do
          deployment_check_report.execute
        end
      end
    end

    context 'when the first notification was already sent' do
      let(:deployment_step) { 'gprd-sidekiq' }

      it 'adds a threaded message' do
        thread_ts = '123456'

        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:read).and_return(thread_ts)

        expect(foreword)
          .to receive(:to_slack_block)

        expect(ReleaseTools::Slack::Message)
          .to receive(:post)
          .with(
            channel: ReleaseTools::Slack::F_UPCOMING_RELEASE,
            message: foreword.header,
            blocks: blocks,
            thread_ts: thread_ts
          )

        without_dry_run do
          deployment_check_report.execute
        end
      end

      context 'when the file does not exist' do
        it 'does not send a message' do
          allow(File).to receive(:exist?).and_return(false)

          expect(ReleaseTools::Slack::Message)
            .not_to receive(:post)

          without_dry_run do
            deployment_check_report.execute
          end
        end
      end
    end

    context 'with a dry_run' do
      it 'does not send any notification' do
        expect(ReleaseTools::Slack::Message)
          .not_to receive(:post)

        deployment_check_report.execute
      end
    end
  end
end
