# frozen_string_literal: true

module ReleaseTools
  module Metrics
    class AutoDeployPressure
      include ::SemanticLogger::Loggable

      METRIC = :delivery_auto_deploy_pressure
      DESCRIPTION = "Number of commits not yet deployed to an environment"
      LABELS = %i[role].freeze

      # The order of these roles is important, and should reflect the order in
      # which we roll out environments.
      ROLES = %w[gstg gprd-cny gprd].freeze

      def initialize
        @prometheus = ReleaseTools::Prometheus::Query.new
        @registry = ::Prometheus::Client::Registry.new
        @metric = @registry.gauge(METRIC, docstring: DESCRIPTION, labels: LABELS)
        @push = Metrics::Push.new(METRIC)
      end

      def execute
        # Index counts by gitlab-rails SHA so multiple environments running
        # the same version only perform one API call
        counts = {}

        versions = @prometheus.rails_version_by_role

        ROLES.each_with_index do |role, i|
          sha = versions[role]

          if i.zero?
            # gstg is sha...master
            counts[sha] ||= commit_pressure(sha, Project::GitlabEe.default_branch)
          else
            previous_sha = versions[ROLES[i - 1]]

            # cny is (gstg count) + (sha...gstg_sha)
            # gprd is (cny count) + (sha...cny_sha)
            counts[sha] ||= counts[previous_sha] +
                            commit_pressure(sha, previous_sha)
          end

          logger.info('Auto-deploy pressure', role: role, sha: sha, commits: counts[sha])
          @metric.set(counts[sha], labels: LABELS.zip([role]).to_h)
        end

        @push.replace(@registry)
      end

      private

      # Find the number of commits between two revisions
      #
      # Returns 0 in the event of an API error
      def commit_pressure(from, to)
        return 0 if from == to
        return 0 if from.blank? || to.blank?

        Retriable.with_context(:api) do
          ReleaseTools::GitlabClient
            .compare('gitlab-org/security/gitlab', from: from, to: to)
            .commits
            .count
        end
      rescue Gitlab::Error::ResponseError => ex
        logger.warn(
          "Failed to fetch commit pressure",
          from: from,
          to: to,
          error: ex.message
        )

        0
      end
    end
  end
end
