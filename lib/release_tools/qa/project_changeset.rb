# frozen_string_literal: true

module ReleaseTools
  module Qa
    class ProjectChangeset
      attr_reader :project, :from, :to

      def initialize(project:, from:, to:)
        @project = project
        @from = from
        @to = to

        verify_refs!(from, to)
      end

      def merge_requests
        @merge_requests ||= gather_merge_requests
      end

      def commits
        @commits ||= ReleaseTools::GitlabClient
          .compare(project.security_path, from: from, to: to)
          .commits
      end

      def shas
        commits.map { |commit| commit['id'] }
      end

      private

      def gather_merge_requests
        commits.each_with_object([]) do |commit, mrs|
          commit['message'].match(/See merge request (?<path>\S*)!(?<iid>\d+)/) do |match|
            mrs << retrieve_merge_request(match[:path], match[:iid])
          end
        end
      end

      def retrieve_merge_request(path, iid)
        Retriable.with_context(:api) do
          ReleaseTools::GitlabClient.merge_request(path, iid: iid)
        end
      end

      def verify_refs!(*refs)
        refs.each do |ref|
          begin
            ReleaseTools::GitlabClient.commit(project.security_path, ref: ref)
          rescue Gitlab::Error::NotFound
            raise ArgumentError.new("Invalid ref for this repository: #{ref}")
          end
        end
      end
    end
  end
end
