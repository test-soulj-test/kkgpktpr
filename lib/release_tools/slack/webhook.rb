# frozen_string_literal: true

module ReleaseTools
  module Slack
    class Webhook
      include ::SemanticLogger::Loggable

      NoWebhookURLError = Class.new(StandardError)
      CouldNotPostError = Class.new(StandardError)

      def self.webhook_url
        raise NoWebhookURLError
      end

      def self.fire_hook(text: nil, channel: nil, attachments: [], blocks: [])
        # It's valid for a child class to return an empty String in order to
        # silently skip the notification, rather than aborting entirely
        return unless webhook_url.present?

        body = {}

        body[:text] = text if text.present?
        body[:channel] = channel if channel.present?
        body[:attachments] = attachments if attachments.any?
        body[:blocks] = blocks if blocks.any?

        logger.trace(__method__, body)

        response = HTTP.post(webhook_url, json: body)

        raise CouldNotPostError.new(response.inspect) unless response.status.success?
      end

      # Return a Slack "mrkdwn" element Hash
      def self.mrkdwn(text)
        {
          type: 'mrkdwn',
          text: text
        }
      end
    end
  end
end
