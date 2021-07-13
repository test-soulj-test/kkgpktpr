# frozen_string_literal: true

module ReleaseTools
  module Services
    class HelmChartPublishService < BasePublishService
      def play_stages
        @play_stages ||= %w[package].freeze
      end

      def release_versions
        @release_versions ||= [
          "v#{@version}"
        ]
      end

      def project
        @project ||= Project::HelmGitlab
      end
    end
  end
end
