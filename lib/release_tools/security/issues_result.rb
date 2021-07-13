# frozen_string_literal: true

module ReleaseTools
  module Security
    class IssuesResult
      def initialize(issues: [], pending: [], ready: [])
        @issues = issues
        @pending = pending
        @ready = ready
      end

      def build_attachments
        attachments = [
          {
            type: 'header',
            text: {
              type: 'plain_text',
              text: "Security Implementation Issues: #{@issues.length}"
            }
          }
        ]

        attachments.concat(summary)
        attachments.concat(pending_attachments)
      end

      private

      def summary
        [
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: "*:white_check_mark: Ready: `#{@ready.length}`       :warning: Pending: `#{@pending.length}`*"
            }
          },
          {
            type: 'divider'
          }
        ]
      end

      def pending_attachments
        return [] if @pending.empty?

        [
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: "* :warning: Pending security issues: #{@pending.length}*"
            }
          },
          {
            type: 'section',
            text: pending_issues_details
          }
        ]
      end

      def pending_issues_details
        {
          type: 'mrkdwn',
          text: @pending.map do |issue|
            "• <#{issue.web_url}|#{issue.reference}> - #{issue.pending_reason}"
          end.join("\n")
        }
      end
    end
  end
end
