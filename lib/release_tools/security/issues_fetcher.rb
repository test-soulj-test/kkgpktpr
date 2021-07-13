# frozen_string_literal: true

module ReleaseTools
  module Security
    # Fetches issues associated to the Security Release Tracking Issue
    # that are ready to be processed
    class IssuesFetcher
      include ::SemanticLogger::Loggable

      def initialize(client)
        @client = client
        @ready = []
        @pending = []
      end

      def execute
        return [] if security_issues.empty?

        logger.info("#{security_issues.count} associated to the Security Release Tracking issue.")

        @ready, @pending = security_issues
          .reject(&:processed?)
          .partition(&:ready_to_be_processed?)

        display_issues_result

        @ready
      end

      private

      def security_issues
        @security_issues ||=
          Security::IssueCrawler
            .new
            .upcoming_security_issues_and_merge_requests
      end

      def display_issues_result
        issues_result = IssuesResult.new(
          issues: security_issues,
          ready: @ready,
          pending: @pending
        )

        Slack::ChatopsNotification.security_implementation_issues_processed(issues_result)

        return if @pending.empty?

        @pending.each do |issue|
          logger.warn("Unable to process security issue", url: issue.web_url, pending_reason: issue.pending_reason)
        end
      end
    end
  end
end
