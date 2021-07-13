# frozen_string_literal: true

module ReleaseTools
  module Promotion
    module Checks
      # ProductionIssueTracker is an abstract class implementing a ReleaseTools::Promotion::Check
      # for open issues on our production tracker
      module ProductionIssueTracker
        include ::ReleaseTools::Promotion::Check

        PRODUCTION = Project::Infrastructure::Production

        # labels is a comma-separated list of labels to search for
        def labels
          raise NotImplementedError
        end

        # filter will filter issues to select blockers
        #
        # @param issue [Gitlab::ObjectifiedHash] the issue to filter
        # @return [Boolean] if the issue should be included as a blocker
        def filter(issue)
          raise NotImplementedError
        end

        # issues select production tracker issues.
        #
        # @see labels for selecting labels
        # @see filter for filtering individual issues
        # @return [Array<GitLab::ObjectifiedHash>] the fetched issues
        def issues
          @issues ||= Retriable.with_context(:api) do
            GitlabClient.issues(PRODUCTION, state: 'opened', labels: labels)
              .select { |issue| filter(issue) }
          end
        end

        # @see Check#fine?
        def fine?
          issues.empty?
        end

        # @see Check#to_issue_body
        def to_issue_body
          text = StringIO.new

          text.puts("#{icon(self)} Production has #{fine? ? 'no ' : ''}#{name}\n")
          issues.each do |issue|
            text.puts("* #{issue.web_url}")
          end

          text.string
        end

        # @see Check#to_slack_block
        def to_slack_blocks
          text = StringIO.new
          text.puts("#{icon(self)} *#{name}*")

          issues.each do |issue|
            text.puts("<#{issue.web_url}|#{issue.title}>")
          end
          [
            {
              type: 'section',
              text: mrkdwn(text.string)
            }
          ]
        end
      end
    end
  end
end
