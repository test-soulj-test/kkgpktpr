# frozen_string_literal: true

module ReleaseTools
  module Security
    class CloseImplementationIssues
      include ::SemanticLogger::Loggable

      def initialize
        @client = ReleaseTools::Security::Client.new
      end

      def execute
        issues = ReleaseTools::Security::IssueCrawler
          .new
          .upcoming_security_issues_and_merge_requests

        return if issues.empty?

        issues.each do |issue|
          next unless issue.processed?

          logger.info('Security implementation issue processed', issue: issue.web_url)

          next if SharedStatus.dry_run?

          @client.close_issue(issue.project_id, issue.iid)
        end
      end
    end
  end
end
