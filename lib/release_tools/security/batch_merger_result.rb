# frozen_string_literal: true

module ReleaseTools
  module Security
    class BatchMergerResult
      attr_accessor :processed, :unprocessed

      def initialize
        @processed = []
        @unprocessed = []
      end

      def build_attachments
        return [] if @processed.empty? && @unprocessed.empty?

        attachments = [
          {
            type: 'divider'
          }
        ]

        attachments.concat(processed_attachments)
        attachments.concat(unprocessed_attachments)
      end

      private

      def processed_attachments
        return [] if @processed.empty?

        [
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: '*:white_check_mark: Processed:*'
            }
          },
          {
            type: 'section',
            text: issues_details(@processed)
          }
        ]
      end

      def unprocessed_attachments
        return [] if @unprocessed.empty?

        [
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: '*:red_circle: Unprocessed:*'
            }
          },
          {
            type: 'section',
            text: issues_details(@unprocessed)
          }
        ]
      end

      def issues_details(issues)
        {
          type: 'mrkdwn',
          text: issues.map { |issue| "• <#{issue.web_url}|#{issue.reference}>" }.join("\n")
        }
      end
    end
  end
end
