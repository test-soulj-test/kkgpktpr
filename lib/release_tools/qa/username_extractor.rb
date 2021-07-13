# frozen_string_literal: true

module ReleaseTools
  module Qa
    class UsernameExtractor
      COMMUNITY_CONTRIBUTION_LABEL = "Community contribution"

      attr_reader :merge_request

      def initialize(merge_request)
        @merge_request = merge_request
      end

      def extract_username
        username_format(mention_for_mr)
      end

      private

      def mention_for_mr
        if merge_request.labels.include?(COMMUNITY_CONTRIBUTION_LABEL)
          merge_request.merged_by&.username ||
            merge_request.assignee&.username ||
            merge_request.author.username
        else
          merge_request.author.username
        end
      end

      def username_format(username)
        "@#{username}"
      end
    end
  end
end
