# frozen_string_literal: true

module ReleaseTools
  module CherryPick
    # Represents the result of a cherry pick
    class Result
      attr_reader :merge_request
      attr_reader :reason

      # merge_request - The merge request we attempted to pick
      # status        - Status of the pick (`:success` or `:failure`)
      def initialize(merge_request, status, reason = nil)
        @merge_request = merge_request
        @status = status
        @reason = reason
      end

      def success?
        @status == :success
      end

      def denied?
        @status == :denied
      end

      def failure?
        !success?
      end

      def title
        merge_request.title
      end

      def url
        merge_request.web_url
      end

      def to_markdown
        "[#{title}](#{url})"
      end
    end
  end
end
