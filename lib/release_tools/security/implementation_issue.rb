# frozen_string_literal: true

module ReleaseTools
  module Security
    class ImplementationIssue
      include ::SemanticLogger::Loggable

      # Number of merge requests that has to be associated to every Security Issue
      MERGE_REQUESTS_SIZE = 4

      # Internal ID of GitLab Release Bot
      GITLAB_RELEASE_BOT_ID = 2_324_599

      # Format of stable branches on GitLab repos
      STABLE_BRANCH_REGEX = /^(\d+-\d+-stable(-ee)?)$/.freeze

      # Internal ID of GitLab Security project
      GITLAB_ID = 15_642_544

      # Internal ID of Omnibus GitLab Security project
      OMNIBUS_ID = 15_667_093

      # Collection of security projects with auto-deploy branch
      PROJECTS_WITH_AUTO_DEPLOY_BRANCH = [GITLAB_ID, OMNIBUS_ID].freeze

      # Collection of security projects that are allowed to early merge
      PROJECTS_ALLOWED_TO_EARLY_MERGE = [GITLAB_ID].freeze

      DEFAULT_BRANCHES = %w[main master].freeze # rubocop:disable ReleaseTools/DefaultBranchLiteral

      # The status of merge requests to be considered
      OPENED = 'opened'

      MERGED = 'merged'

      ALLOWED_DEFAULT_MR_STATE = [OPENED, MERGED].freeze

      attr_reader :project_id, :iid, :web_url, :reference, :merge_requests, :pending_reason

      def initialize(issue, merge_requests)
        @project_id = issue.project_id
        @iid = issue.iid
        @web_url = issue.web_url
        @reference = issue.references.full

        @merge_requests = merge_requests
        @pending_reason = nil
      end

      def ready_to_be_processed?
        if merge_requests.length < MERGE_REQUESTS_SIZE
          reject('missing merge requests')
        elsif !merge_requests_with_allowed_status?
          reject('invalid merge requests status')
        elsif !merge_requests_assigned_to_the_bot?
          reject('unassigned merge requests')
        elsif !valid_merge_requests?
          reject('invalid merge requests')
        else
          true
        end
      end

      def reject(reason)
        logger.warn("Rejecting implementation issue due to #{reason}", url: web_url)

        @pending_reason = reason

        false
      end

      def merge_request_targeting_default_branch
        merge_requests
          .detect { |merge_request| DEFAULT_BRANCHES.include?(merge_request.target_branch) }
      end

      def backports
        merge_requests
          .select { |merge_request| merge_request.target_branch.match?(STABLE_BRANCH_REGEX) }
      end

      def project_with_auto_deploy?
        PROJECTS_WITH_AUTO_DEPLOY_BRANCH.include?(project_id)
      end

      def processed?
        merge_requests.all? { |mr| mr.state == MERGED }
      end

      def allowed_to_early_merge?
        merge_request_targeting_default_branch&.state == OPENED &&
          PROJECTS_ALLOWED_TO_EARLY_MERGE.include?(merge_request_targeting_default_branch.project_id)
      end

      def pending_merge_requests
        if PROJECTS_ALLOWED_TO_EARLY_MERGE.include?(project_id)
          backports
        else
          merge_requests
            .select { |merge_request| merge_request.state == OPENED }
        end
      end

      private

      def merge_requests_assigned_to_the_bot?
        merge_requests.all? do |merge_request|
          merge_request
            .assignees
            .map { |assignee| assignee.transform_keys(&:to_sym)[:id] }.include?(GITLAB_RELEASE_BOT_ID)
        end
      end

      def merge_requests_with_allowed_status?
        default_branch_state = merge_request_targeting_default_branch&.state

        ALLOWED_DEFAULT_MR_STATE.include?(default_branch_state) &&
          backports.all? { |mr| mr.state == OPENED }
      end

      def valid_merge_requests?
        invalid_mrs = ReleaseTools::Security::MergeRequestsValidator
          .new(ReleaseTools::Security::Client.new)
          .execute(merge_requests: merge_requests)
          .last

        invalid_mrs.empty?
      end
    end
  end
end
