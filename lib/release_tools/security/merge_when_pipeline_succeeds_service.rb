# frozen_string_literal: true

module ReleaseTools
  module Security
    class MergeWhenPipelineSucceedsService < ReleaseTools::Services::MergeWhenPipelineSucceedsService
      def initialize(client, merge_request)
        @client = client
        @merge_request = merge_request
      end

      def execute
        Retriable.with_context(:api) do
          trigger_pipeline

          wait_for_mr_pipeline_to_start

          merge_when_pipeline_succeeds
        end
      rescue PipelineNotReadyError
        logger.warn('Pipeline not ready', merge_request: merge_request.web_url)
      end

      private

      def trigger_pipeline
        logger.info('Triggering pipeline for merged results', merge_request: merge_request.web_url)

        return if SharedStatus.dry_run?

        GitlabClient.create_merge_request_pipeline(
          @merge_request.project_id,
          @merge_request.iid
        )
      end

      def merge_when_pipeline_succeeds
        return if SharedStatus.dry_run?

        logger.info('Setting MWPS', merge_request: merge_request.web_url)

        params = {
          merge_when_pipeline_succeeds: true,
          squash: true,
          should_remove_source_branch: true
        }

        @client.accept_merge_request(
          @merge_request.project_id,
          @merge_request.iid,
          params
        )
      end
    end
  end
end
