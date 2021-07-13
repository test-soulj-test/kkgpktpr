# frozen_string_literal: true

module ReleaseTools
  module Metrics
    module CoordinatedDeployment
      class Duration
        include ::SemanticLogger::Loggable

        # deploy_version: Omnibus package to be deployed
        # start_time: Start time as a string of the deployment
        def initialize(deploy_version:, start_time:)
          @deploy_version = deploy_version
          @start_time = start_time.nil? ? start_time : Time.parse(start_time)
          @end_time = Time.now.utc
        end

        def execute
          return unless Feature.enabled?(:measure_deployment_duration)
          return if @start_time.nil?

          logger.info('Recording duration', deploy_version: @deploy_version, start_time: @start_time, end_time: @end_time, duration: duration_in_seconds)

          record_histogram_metric
        end

        private

        def record_histogram_metric
          ::ReleaseTools::Metrics::Client.new.observe(
            'deployment_duration_seconds',
            duration_in_seconds,
            labels: 'coordinator_pipeline,success'
          )
        end

        def duration_in_seconds
          @end_time - @start_time
        end
      end
    end
  end
end
