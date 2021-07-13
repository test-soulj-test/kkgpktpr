# frozen_string_literal: true

module ReleaseTools
  module Services
    # MergeWhenPipelineSucceedsService will approve a merge request and set it
    # to merge when pipeline succeeds
    class MergeWhenPipelineSucceedsService
      include ::SemanticLogger::Loggable

      SelfApprovalError = Class.new(ArgumentError)
      InvalidMergeRequestError = Class.new(ArgumentError)
      PipelineNotReadyError = Class.new(StandardError)

      # we consider a pipeline ready only when in one of the following states
      PIPELINE_READY_STATES = %w[running pending].freeze

      attr_reader :client, :merge_request

      # Initialize the service
      #
      # @param merge_request [ReleaseTools::MergeRequest] the merge request to approve and MWPS
      # @param token [string] the GitLab private token, it should not belong to the merge request's author
      # @param endpoint [string] the GitLab API endpoint
      def initialize(merge_request, token:, endpoint: GitlabClient::DEFAULT_GITLAB_API_ENDPOINT)
        @client = Gitlab::Client.new(endpoint: endpoint, private_token: token)
        @merge_request = merge_request
      end

      # execute starts the service operations
      #
      # This method is idempotent
      #
      # @raise [SelfApprovalError] when the token belongs to merge_request's author
      # @raise [InvalidMergeRequestError] when the merge request is not valid
      # @raise [PipelineNotReadyError] when cannot find a ready pipeline for the merge request
      def execute
        Retriable.with_context(:api) do
          validate!

          approve unless approved?

          # we need to wait for the pipeline to start or we cannot set merge_when_pipeline_succeeds
          wait_for_mr_pipeline_to_start

          merge_when_pipeline_succeeds
        end
      end

      def approved?
        client.merge_request_approvals(project_id, iid).approved
      end

      def approve
        logger.info('Approving merge request', merge_request: url)

        client.approve_merge_request(project_id, iid) unless SharedStatus.dry_run?
      end

      def merge_when_pipeline_succeeds
        return if SharedStatus.dry_run?

        client.accept_merge_request(
          project_id,
          iid,
          merge_when_pipeline_succeeds: true,
          should_remove_source_branch: true
        )
      end

      # Validates the merge request exists and the current user can approve it
      #
      # @raise [SelfApprovalError] when the approver is the author
      # @raise [InvalidMergeRequestError] when the merge request does not exist
      def validate!
        author = merge_request&.author&.id
        raise InvalidMergeRequestError if author.nil?

        current_user = client.user.id
        raise SelfApprovalError if author == current_user
      end

      private

      def project_id
        merge_request.project_id
      end

      def iid
        merge_request.iid
      end

      def url
        merge_request.url
      end

      def wait_for_mr_pipeline_to_start
        logger.info('Waiting for a merge request pipeline')

        return if SharedStatus.dry_run?

        # pipeline for merge requests will be generated only after creating the merge request.
        # here we wait until the pipeline is created with an exponential back-off
        # In case of a high load, creating the pipeline may take more than 1 minute.
        # base_interval 5 and tries 10 will hit the 1 minute timeline on retry n 5 (in average)
        # and wait up to 6 minutes (in average) on the worst case.
        Retriable.retriable(base_interval: 5, tries: 10, on: [PipelineNotReadyError, ::Gitlab::Error::ResponseError]) do
          pipeline = latest_pipeline

          raise PipelineNotReadyError unless PIPELINE_READY_STATES.include?(pipeline&.status)

          logger.info('Merge request pipeline', pipeline: pipeline.web_url, status: pipeline.status.to_s)

          pipeline
        end
      end

      def latest_pipeline
        client.pipelines(project_id, ref: merge_pipeline_ref, per_page: 1).first
      end

      def merge_pipeline_ref
        "refs/merge-requests/#{iid}/merge"
      end
    end
  end
end
