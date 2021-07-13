# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Slack::Webhook do
  include SlackWebhookHelpers

  describe '.fire_hook' do
    context 'without webhook_url' do
      it 'raises NoWebhookURLError' do
        expect { described_class.fire_hook(text: 'foo') }
          .to raise_error(described_class::NoWebhookURLError)
      end
    end

    context 'with empty webhook_url' do
      it 'raises no error' do
        allow(described_class).to receive(:webhook_url).and_return('')

        expect { described_class.fire_hook(text: 'foo') }.not_to raise_error
      end
    end

    context 'with webhook_url' do
      let(:text) { 'Hello!' }
      let(:webhook_url) { 'https://slack.example.com/' }

      before do
        # This would normally raise NoWebhookURLError, but we're testing an
        # abstract class
        allow(described_class).to receive(:webhook_url).and_return(webhook_url)
      end

      context 'when channel is not given' do
        it 'posts to the given url with the given arguments' do
          expect_post(json: { text: text }).and_return(response(200))

          described_class.fire_hook(text: text)
        end

        context 'when response is not successfull' do
          it 'raises CouldNotPostError' do
            expect_post(json: { text: text }).and_return(response(400))

            expect { described_class.fire_hook(text: text) }
              .to raise_error(described_class::CouldNotPostError)
          end
        end
      end

      context 'when channel is given' do
        it 'passes the given channel' do
          channel = '#ce-to-ee'

          expect_post(json: { text: text, channel: channel })
            .and_return(response(200))

          described_class.fire_hook(channel: channel, text: text)
        end
      end

      context 'when attachments are given' do
        it 'passes the attachments' do
          attachments = [{ title: 'foo' }]

          expect_post(json: { attachments: attachments })
            .and_return(response(200))

          described_class.fire_hook(attachments: attachments)
        end
      end
    end
  end
end
