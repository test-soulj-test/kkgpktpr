# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    # Waits for a pipeline to complete
    class WaitForPipeline
      include ::SemanticLogger::Loggable
      include ReleaseTools::AutoDeploy::Pipeline

      def initialize(client, project, pipeline_id)
        @client = client
        @project = project
        @pipeline_id = pipeline_id
      end

      def execute
        Retriable.with_context(:package_pipeline, on: RunningPipelineError) do
          check_status!
        end

        true
      rescue PipelineError => ex
        logger.warn(ex.message, { pipeline: ex.pipeline&.web_url }.compact)

        slack_notification(ex) if ReleaseTools::Feature.disabled?(:disable_deploy_wait_failure_slack_notification)

        false
      end

      private

      def check_status!
        Retriable.with_context(:api) do
          logger.debug('Checking status of pipeline', project: @project, pipeline_id: @pipeline_id)

          pipeline = @client.pipeline(
            @project,
            @pipeline_id
          )

          raise MissingPipelineError.new unless pipeline

          logger.debug('Got pipeline status', status: pipeline.status)

          raise RunningPipelineError.new(pipeline) if WAITING_STATUSES.include?(pipeline.status)
          raise FailedPipelineError.new(pipeline) if FAILURE_STATUSES.include?(pipeline.status)
        end
      end

      def slack_notification(exception)
        ::ReleaseTools::Slack::AutoDeployNotification.on_wait_failure(exception)
      end
    end
  end
end
