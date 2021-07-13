# frozen_string_literal: true

module ReleaseTools
  module Promotion
    # Check is a public interface to implement a production check
    module Check
      # @return [String] a human friendly name
      def name
        raise NotImplementedError
      end

      # fine? is the result of the check
      #
      # @return [Boolen] if `true` the deployment is allowed
      def fine?
        false
      end

      # to_issue_body returns the check representation for the monthly release issue
      #
      # @return [String]
      def to_issue_body
        raise NotImplementedError
      end

      # to_slack_blocks returns an array of Slack block representations of the check
      #
      # @see https://api.slack.com/reference/block-kit/blocks Slack blocks reference
      # @return Array<Hash> an array of hashes conforming to slack blocks specifications
      def to_slack_blocks
        raise NotImplementedError
      end

      def ok_icon
        ':white_check_mark:'
      end

      def failure_icon
        ':red_circle:'
      end

      def icon(check)
        if check.fine?
          ok_icon
        else
          failure_icon
        end
      end

      def mrkdwn(text)
        ::ReleaseTools::Slack::Webhook.mrkdwn(text)
      end
    end
  end
end
