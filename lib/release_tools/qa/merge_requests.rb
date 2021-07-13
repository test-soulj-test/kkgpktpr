# frozen_string_literal: true

module ReleaseTools
  module Qa
    class MergeRequests
      def initialize(projects:, from:, to:)
        @projects = projects
        @from = from
        @to = to
      end

      def to_a
        ReleaseTools::Qa::IssuableOmitterByLabels.new(merge_requests).execute
      end

      def merge_requests
        changesets = @projects.map do |project|
          ReleaseTools::Qa::ProjectChangeset.new(
            project: project,
            from: @from.for_project(project),
            to: @to.for_project(project)
          )
        end

        changesets.flat_map(&:merge_requests).uniq(&:id)
      end
    end
  end
end
