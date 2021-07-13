# frozen_string_literal: true

require 'sentry-raven'

module ReleaseTools
  module Promotion
    class StatusNote
      attr_reader :status, :package_version, :ci_pipeline_url, :release_manager, :override_status, :override_reason

      # rubocop:disable Metrics/ParameterLists
      def initialize(status:, package_version:, release_manager:, override_status:, override_reason:, ci_pipeline_url: nil)
        @status = status
        @package_version = package_version
        @ci_pipeline_url = ci_pipeline_url
        @release_manager = release_manager
        @override_status = override_status
        @override_reason = override_reason
      end
      # rubocop:enable Metrics/ParameterLists

      def body
        ERB
          .new(template, trim_mode: '-') # Omit blank lines when using `<% -%>`
          .result(binding)
      end

      private

      def template
        template_path = File.expand_path('../../../templates/status_note.md.erb', __dir__)

        File.read(template_path)
      end
    end
  end
end
