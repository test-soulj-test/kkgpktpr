# frozen_string_literal: true

module ReleaseTools
  module Qa
    # Automatic closing of QA issues after their deadline has expired.
    class IssueCloser
      # The date format to use when parsing the deadline string.
      DEADLINE_FORMAT = '%Y-%m-%d %H:%M'

      # The comment the bot should post before closing the issue.
      CLOSING_NOTE = <<~NOTE.strip
        The deadline for this QA task has expired, and this issue will be closed.
      NOTE

      # The regex to use for figuring out what the deadline is for a QA issue. Due
      # dates sadly can't be used, as they don't support specifying a time.
      #
      # This pattern will look for text such as the following:
      #
      #     ... should be completed by 2019-02-13 13:53 UTC ...
      DEADLINE_REGEX = /should be completed by \*\*(?<deadline>[^*]+)\*\*/.freeze

      def execute
        qa_issues.each do |issue|
          close_issue(issue) if close_issue?(issue)
        end
      end

      def close_issue?(issue)
        deadline = deadline_for(issue)

        deadline && deadline_expired?(deadline) ? true : false
      end

      def close_issue(issue)
        ReleaseTools::GitlabClient.create_issue_note(
          ReleaseTools::Project::Release::Tasks,
          issue: issue,
          body: CLOSING_NOTE
        )

        ReleaseTools::GitlabClient.close_issue(
          ReleaseTools::Project::Release::Tasks,
          issue
        )
      end

      def deadline_for(issue)
        matches = issue.description.match(DEADLINE_REGEX)

        if matches && matches[:deadline]
          Time.strptime(matches[:deadline], DEADLINE_FORMAT)
        end
      end

      def deadline_expired?(deadline)
        Time.now.utc >= deadline
      end

      def qa_issues
        ReleaseTools::GitlabClient.issues(
          Project::Release::Tasks,
          labels: 'QA task',
          state: 'opened'
        )
      end
    end
  end
end
