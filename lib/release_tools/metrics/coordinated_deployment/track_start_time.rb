# frozen_string_literal: true

module ReleaseTools
  module Metrics
    module CoordinatedDeployment
      class TrackStartTime
        include ::SemanticLogger::Loggable

        def execute
          return unless Feature.enabled?(:measure_deployment_duration)

          start_time = Time.now.utc

          logger.info('Recording start time', start_time: start_time)

          File.open('deploy_vars.env', 'a') do |deploy_vars|
            deploy_vars << "DEPLOY_START_TIME='#{start_time}'"
          end
        end
      end
    end
  end
end
