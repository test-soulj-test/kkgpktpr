# frozen_string_literal: true

module ReleaseTools
  module Slack
    class Message
      include ::SemanticLogger::Loggable

      API_URL = 'https://slack.com/api/chat.postMessage'

      NoCredentialsError = Class.new(StandardError)
      CouldNotPostMessageError = Class.new(StandardError)

      def self.post(channel:, message:, blocks: [], thread_ts: nil, mrkdwn: nil)
        raise NoCredentialsError unless slack_token.present?

        params = {
          channel: channel,
          text: message,
          as_user: true,
          mrkdwn: mrkdwn
        }.compact

        params[:blocks] = blocks if blocks.any?
        params[:thread_ts] = thread_ts if thread_ts.present?

        logger.trace(__method__, params)

        response = client.post(
          API_URL,
          json: params
        )

        raise CouldNotPostMessageError.new(response.inspect) unless response.status.success?

        JSON.parse(response.body)
      end

      def self.client
        @client ||= HTTP.auth("Bearer #{slack_token}")
      end

      def self.slack_token
        ENV.fetch('SLACK_TOKEN', '')
      end
    end
  end
end
