# frozen_string_literal: true

module ReleaseTools
  module Security
    # Merging valid security merge requests
    class MergeRequestsMerger
      include ::SemanticLogger::Loggable

      PICKABLE_TARGETS = %w[master main].freeze # rubocop:disable ReleaseTools/DefaultBranchLiteral

      # @param [ReleaseTools::Security::Client] client
      def initialize(merge_default: false)
        @client = ReleaseTools::Security::Client.new
        @result = BatchMergerResult.new
        @merge_default = merge_default
      end

      # Processes valid security merge requests:
      #
      # 1. Fetches security implementation issues that are ready
      #    to be processed.
      # 2. Iterates over security implementation issues
      # 3. If `merge_default`, only the merge request targeting the default branch is processed.
      #    Else, the backports and pending merge requests are processed.
      def execute
        security_implementation_issues.each do |security_issue|
          process_merge_requests(security_issue)
        end

        notify_result
      end

      private

      def security_implementation_issues
        Security::IssuesFetcher
          .new(@client)
          .execute
      end

      def validated_merge_requests(merge_requests)
        MergeRequestsValidator
          .new(@client)
          .execute(merge_requests: merge_requests)
      end

      def process_merge_requests(security_issue)
        if @merge_default
          process_mr_targeting_default(security_issue)
        else
          process_pending_merge_requests(security_issue)
        end
      end

      # Processes merge request targeting the default branch for GitLab Security
      # issues by triggering a new pipeline and setting MWPS
      def process_mr_targeting_default(security_issue)
        return unless security_issue.allowed_to_early_merge?

        logger.info('Processing merge request targeting default branch', issue: security_issue.web_url)

        mr_default = security_issue.merge_request_targeting_default_branch

        ReleaseTools::Security::MergeWhenPipelineSucceedsService
          .new(@client, mr_default)
          .execute

        @result.processed << security_issue
      end

      # Processes pending merge requests:
      #
      # - For GitLab Security issues, the backports are processed.
      # - For the rest of the projects, all security merge requests
      #   are processed.
      def process_pending_merge_requests(security_issue)
        logger.info('Merging pending merge_requests', issue: security_issue.web_url)

        security_issue.pending_merge_requests.each do |merge_request|
          merge_merge_request(security_issue, merge_request)
        end
      end

      def merge_merge_request(security_issue, merge_request)
        logger.trace(__method__, merge_request: merge_request.web_url)

        return if SharedStatus.dry_run? || merge_request.state == 'merged'

        merged_result = @client.accept_merge_request(
          merge_request.project_id,
          merge_request.iid,
          squash: true,
          should_remove_source_branch: true
        )

        if merged_result.respond_to?(:merge_commit_sha) && merged_result.merge_commit_sha.present?
          logger.info("Merged security merge request", url: merge_request.web_url)

          cherry_pick_into_auto_deploy(security_issue, merged_result) if can_be_cherry_picked?(security_issue, merge_request)
        else
          logger.fatal("Merge request #{merge_request.web_url} couldn't be merged")

          @result.unprocessed << security_issue
        end
      end

      def can_be_cherry_picked?(security_issue, merge_request)
        security_issue.project_with_auto_deploy? &&
          PICKABLE_TARGETS.include?(merge_request.target_branch)
      end

      def cherry_pick_into_auto_deploy(security_issue, merge_request)
        ReleaseTools::Security::CherryPicker
          .new(@client, merge_request)
          .execute

        @result.processed << security_issue
      end

      def notify_result
        Slack::ChatopsNotification.security_merge_requests_processed(@result)
      end
    end
  end
end
