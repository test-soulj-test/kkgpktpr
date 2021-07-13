# frozen_string_literal: true

module ReleaseTools
  module Promotion
    module Checks
      # ActiveIncidents checks for active incidents issue with at least severity::2
      class ActiveIncidents
        BLOCKING_LABELS = %w[severity::1 severity::2].freeze

        include ProductionIssueTracker

        def name
          'active incidents'
        end

        def labels
          'Incident::Active'
        end

        def filter(issue)
          BLOCKING_LABELS.any? { |b| issue.labels.include?(b) }
        end
      end
    end
  end
end
