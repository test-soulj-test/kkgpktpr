# frozen_string_literal: true

module ReleaseTools
  module Metrics
    class ReleasePressure
      include ::SemanticLogger::Loggable

      METRIC = :delivery_release_pressure
      DESCRIPTION = 'Number of `Pick into` merge requests for previous releases'
      LABELS = %i[state version severity].freeze

      STATES = %w[merged].freeze
      SEVERITIES = %w[none severity::1 severity::2 severity::3 severity::4].freeze
      MAX_VERSIONS = 3

      def initialize
        @registry = ::Prometheus::Client::Registry.new
        @metric = @registry.gauge(METRIC, docstring: DESCRIPTION, labels: LABELS)
        @push = Metrics::Push.new(METRIC)
      end

      def execute
        pick_labels.each do |pick_label|
          version = pick_label.delete_prefix('Pick into ')

          STATES.each do |state|
            all = merge_requests(pick_label, state)
            buckets = severity_buckets(all)

            buckets.each do |severity, merge_requests|
              count = merge_requests.size
              labels = LABELS.zip([state, version, severity]).to_h

              logger.info('Release pressure', labels.merge(count: count))
              @metric.set(count, labels: labels)
            end
          end
        end

        @push.replace(@registry)
      end

      private

      def pick_labels
        ReleaseTools::Versions
          .latest(ReleaseTools::Versions.current, MAX_VERSIONS)
          .map { |v| ReleaseTools::Version.new(v) }
          .map { |v| ReleaseTools::PickIntoLabel.for(v) }
      end

      # Find merge requests with a specific label and state
      #
      # Returns an empty Array in the event of an API error
      def merge_requests(label, state)
        Retriable.with_context(:api) do
          ReleaseTools::GitlabClient
            .client
            .user_merge_requests(scope: 'all', labels: label, state: state)
            .auto_paginate
        end
      rescue Gitlab::Error::Error => ex
        logger.warn(
          'Failed to fetch release pressure',
          label: label,
          state: state,
          error: ex.message
        )

        []
      end

      # Group an Array of merge requests into a Hash indexed by their severity
      #
      # Uses a key of `none` when a merge request does not have a severity
      # label.
      def severity_buckets(merge_requests)
        buckets = SEVERITIES.map { |key| [key, []] }.to_h

        merge_requests.each do |mr|
          key = mr.labels.detect do |label|
            label.match?(/^severity::[1-4]$/)
          end || SEVERITIES.first

          buckets[key] << mr
        end

        buckets
      end
    end
  end
end
