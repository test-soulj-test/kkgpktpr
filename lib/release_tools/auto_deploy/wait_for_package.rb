# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    # Finds a packager pipeline for the current coordinated pipeline and waits
    # for it to complete
    class WaitForPackage
      include ::SemanticLogger::Loggable
      include ReleaseTools::AutoDeploy::Pipeline

      # project      - Project object
      # release_name - Packager name used as a ReleaseMetadata key
      def initialize(project, release_name)
        @project = project
        @release_name = release_name
      end

      # Find a packager pipeline and wait for it to complete
      #
      # If the pipeline has completed successfully, it will return `true`.
      #
      # If the pipeline hasn't yet been created, it will retry for a set
      # interval before returning `false`.
      #
      # If the pipeline is still running, it will retry for a set interval
      # before returning `false`.
      #
      # If the pipeline has failed, it will immediately return `false`.
      def execute
        ref = find_ref

        pipeline = Retriable.with_context(:pipeline_created, on: MissingPipelineError) do
          find_pipeline!(ref)
        end

        Retriable.with_context(:package_pipeline, on: RunningPipelineError) do
          check_status!(pipeline)
        end

        true
      rescue PipelineError => ex
        logger.warn(ex.message, { pipeline: ex.pipeline&.web_url }.compact)

        slack_notification(ex)

        false
      end

      private

      def find_ref
        ReleaseTools::AutoDeploy::Tag.new.component_ref(component: @release_name)
      end

      # Get the latest pipeline for a given ref
      #
      # Raises MissingPipelineError if no pipelines are found.
      def find_pipeline!(ref)
        pipelines = Retriable.with_context(:api) do
          logger.debug('Finding pipelines for ref', ref: ref)

          ReleaseTools::GitlabDevClient.pipelines(
            @project,
            ref: ref,
            order_by: 'id',
            sort: 'desc'
          )
        end

        raise MissingPipelineError if pipelines.empty?

        pipelines.first
      end

      # Check the latest status for a pipeline
      #
      # Raises RunningPipelineError if the pipeline is still running.
      # Raises FailedPipelineError if the pipeline has failed.
      def check_status!(source)
        Retriable.with_context(:api) do
          logger.debug('Checking status of pipeline', pipeline: source.web_url)
          pipeline = ReleaseTools::GitlabDevClient.pipeline(
            @project,
            source.id
          )

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
