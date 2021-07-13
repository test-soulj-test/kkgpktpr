# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Slack::Message do
  describe '.post' do
    let(:slack_channel) { 'foo' }
    let(:message) { 'baz' }

    context 'without credentials' do
      it 'raises NoCredentialsError' do
        ClimateControl.modify(SLACK_TOKEN: nil) do
          expect do
            described_class.post(channel: slack_channel, message: message)
          end.to raise_error(described_class::NoCredentialsError)
        end
      end
    end

    context 'with credentials' do
      let(:fake_client) { double(:client) }

      let(:json_response) do
        {
          ok: true,
          channel: 'foo',
          ts: '123456',
          message: {
            type: 'message',
            subtype: 'bot_message',
            text: message,
            ts: '123456',
            username: 'bot',
            bot_id: 'bar'
          }
        }.to_json
      end

      let(:response) do
        double(
          :response,
          status: double(:status, success?: true),
          body: json_response
        )
      end

      before do
        allow(described_class)
          .to receive(:client).and_return(fake_client)

        allow(fake_client)
          .to receive(:post).and_return(response)
      end

      it 'posts a message on a specific Slack channel' do
        expect(fake_client)
          .to receive(:post)
          .with(
            described_class::API_URL,
            json: {
              channel: slack_channel,
              text: message,
              as_user: true
            }
          )

        ClimateControl.modify(SLACK_TOKEN: '123456') do
          described_class.post(channel: slack_channel, message: message)
        end
      end

      context 'with blocks' do
        it 'sends blocks' do
          blocks = [
            {
              type: 'section',
              text: { type: 'mrkdwn', text: 'foo' }
            }
          ]

          expect(fake_client)
            .to receive(:post)
            .with(
              described_class::API_URL,
              json: {
                channel: slack_channel,
                text: message,
                as_user: true,
                blocks: blocks
              }
            )

          ClimateControl.modify(SLACK_TOKEN: '123456') do
            described_class.post(channel: slack_channel, message: message, blocks: blocks)
          end
        end
      end

      context 'with thread_ts' do
        it 'sends a threaded message' do
          thread_ts = '123456'

          expect(fake_client)
            .to receive(:post)
            .with(
              described_class::API_URL,
              json: {
                channel: slack_channel,
                text: message,
                as_user: true,
                thread_ts: thread_ts
              }
            )

          ClimateControl.modify(SLACK_TOKEN: '123456') do
            described_class.post(channel: slack_channel, message: message, thread_ts: thread_ts)
          end
        end
      end
    end
  end
end
