# frozen_string_literal: true

module ReleaseTools
  module Promotion
    module Checks
      # ChangeRequests checks for in-progress change requests issue with C1 or C2 label
      class ChangeRequests
        include ProductionIssueTracker

        def name
          'change requests in progress'
        end

        def labels
          'change::in-progress'
        end

        def filter(issue)
          issue.labels.include?('C1') || issue.labels.include?('C2')
        end
      end
    end
  end
end
