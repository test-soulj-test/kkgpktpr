# frozen_string_literal: true

module ReleaseTools
  module Security
    class MergeRequestValidator
      attr_reader :errors

      # A regular expression to use for extracting all pending tasks from the
      # merge request description. This pattern will match the following:
      #
      #     - [ ] Task name here
      #     * [ ] Task name here
      PENDING_TASKS = /(\*|-)\s*\[\s+\]/.freeze

      # A regular expression to use for extracting all tasks (pending or not)
      # from the merge request description. This pattern will match the
      # following:
      #
      #     - [ ] Task name here
      #     * [ ] Task name here
      #     - [x] Task name here
      #     * [x] Task name here
      ALL_TASKS = /(\*|-)\s*\[(\s+|[xX])\]/.freeze

      # A regular expression used to determine if the target branch of a merge
      # request is valid.
      ALLOWED_TARGET_BRANCHES = /^(master|main|\d+-\d+-stable(-ee)?)$/.freeze

      # The label that must be applied to all security merge requests.
      SECURITY_LABEL = 'security'

      # The namespace that security implementation issues must reside in.
      SECURITY_NAMESPACE = 'gitlab-org/security'

      # GitLab Security Project ID
      GITLAB_SECURITY_ID = 15_642_544

      # Projects with EE stable branches
      PROJECTS_WITH_EE_BRANCHES = [GITLAB_SECURITY_ID].freeze

      # @param [Gitlab::ObjectifiedHash] merge_request
      # @param [ReleaseTools::Security::Client] client
      def initialize(merge_request, client)
        @merge_request = merge_request
        @client = client
        @errors = []
      end

      def validate
        validate_pipeline_status
        validate_merge_status
        validate_work_in_progress
        validate_pending_tasks
        validate_milestone
        validate_merge_request_template
        validate_target_branch
        validate_discussions
        validate_labels
        validate_approvals
        validate_stable_branches
      end

      def validate_pipeline_status
        pipeline = Pipeline.latest_for_merge_request(@merge_request, @client)

        if pipeline.nil?
          error('Missing pipeline', <<~ERROR)
            No pipeline could be found for this merge request. Security merge
            requests must have a pipeline that passes before they can be merged.
          ERROR
        elsif pipeline.failed?
          error('Failing pipeline', <<~ERROR)
            The latest pipeline has one or more failing builds. Merge requests
            can not be merged unless the pipeline has passed.
          ERROR
        elsif pipeline.pending? || (pipeline.running? && !default_branch?)
          # This covers pipelines that are skipped or in another unknown state.
          #
          # Running pipelines against the default branch are allowed due to
          # https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1231
          error('Pending pipeline', <<~ERROR)
            The latest pipeline did not pass. Merge requests should not be
            assigned to me until the pipeline is successful.
          ERROR
        end
      end

      def validate_merge_status
        if @merge_request.merge_status == 'cannot_be_merged'
          error('The merge request can not be merged', <<~ERROR)
            This merge request can currently not be merged, likely due to merge
            conflicts introduced by other (security) merge requests. Please
            rebase this merge request with the target branch and resolve any
            conflicts.
          ERROR
        end
      end

      def validate_work_in_progress
        if @merge_request.title.start_with?('WIP', 'Draft')
          error('The merge request is marked as a work in progress', <<~ERROR)
            Work in progress merge requests will not be merged, so make sure to
            resolve the WIP status before assigning this merge request back to
            me.
          ERROR
        end
      end

      def validate_pending_tasks
        if @merge_request.description.match?(PENDING_TASKS)
          error('There are one or more pending tasks', <<~ERROR)
            Before a security merge request can be merged, _all_ tasks must have
            been completed. If a task is not applicable, you can either mark it
            as completed or remove it.
          ERROR
        end
      end

      def validate_milestone
        if @merge_request.milestone.nil?
          error('The merge request does not have a milestone', <<~ERROR)
            This merge request does not appear to have a milestone. Backports
            must use the milestone of the version they target. Merge requests
            targeting the default branch should use the latest milestone.
          ERROR
        end
      end

      def validate_merge_request_template
        unless @merge_request.description.match?(ALL_TASKS)
          error('The Security Release template is not used', <<~ERROR)
            This merge request does not contain any tasks to complete,
            suggesting that the "Security Release" merge request template was
            not used. Security merge requests must use this merge request
            template.
          ERROR
        end
      end

      def validate_target_branch
        unless @merge_request.target_branch.match?(ALLOWED_TARGET_BRANCHES)
          error('The target branch is invalid', <<~ERROR)
            Security merge requests must target the default branch, or a stable
            branch such as 11-8-stable-ee.

            Security branches are no longer in use and should not be used as
            target branches.
          ERROR
        end
      end

      def validate_discussions
        # There might be many discussions and notes. Buffering all of those in
        # an Array might require quite a bit of memory, so instead we process
        # discussions as we retrieve them.
        @client
          .merge_request_discussions(@merge_request.project_id, @merge_request.iid)
          .auto_paginate do |discussion|
            if discussion.notes.any? { |n| n['resolvable'] && !n['resolved'] }
              error('There are unresolved discussions', <<~ERROR)
                This merge request has one or more unresolved discussions,
                preventing it from being merged. Please mark all discussions as
                resolved, then assign this merge request back to me.
              ERROR

              break
            end
          end
      end

      def validate_labels
        unless @merge_request.labels.include?(SECURITY_LABEL)
          error(%{The merge request is missing the ~#{SECURITY_LABEL} label}, <<~ERROR)
            This merge request is missing the ~#{SECURITY_LABEL} label. This
            label is added automatically when using the security release merge
            request template. The lack of this label suggests the template may
            not have been used (correctly).

            Merge requests without this label will not be merged.
          ERROR
        end
      end

      # Validates if a merge request has the needed approvals
      #
      # * If it's targeting the default branch, we validate at least two
      #   approvals:
      #   - From a team member (ideally a maintainer, but since there's
      #   no easy way to verify that, we're simply checking any approval)
      #   - From a member of the AppSec team
      #
      # * If it's targeting a stable branch, we validate one approval.
      def validate_approvals
        approvals = @client
          .merge_request_approvals(@merge_request.project_id, @merge_request.iid)

        if default_branch?
          validate_approvals_on_default_branch(approvals)
        else
          validate_approval_on_stable_branch(approvals)
        end
      end

      def validate_stable_branches
        return if default_branch?

        next_versions = next_security_versions

        # When a stable branch is created for an upcoming monthly release, but
        # the release hasn't yet been completed and there's no
        # version.gitlab.com entry, `next_security_versions` won't return the
        # correct versions for the maintenance window. Fake it by taking the
        # highest version and adding the next minor (monthly) version.
        next_versions.prepend(Version.new(next_versions.first.next_minor))

        stable_branches =
          if PROJECTS_WITH_EE_BRANCHES.include?(@merge_request.project_id)
            next_security_versions.map do |version|
              version.stable_branch(ee: true)
            end
          else
            next_security_versions.map(&:stable_branch)
          end

        return if stable_branches.any? { |branch| @merge_request.target_branch.match?(/\A#{branch}(-ee)?\z/) }

        error('The merge request is targeting a stable branch out of the maintenance policy', <<~ERROR)
          This merge request should target any of the following stable
          branches: #{stable_branches.join(', ')}
        ERROR
      end

      private

      # rubocop:disable ReleaseTools/DefaultBranchLiteral
      def default_branch?
        @merge_request.target_branch == 'master' || @merge_request.target_branch == 'main'
      end
      # rubocop:enable ReleaseTools/DefaultBranchLiteral

      def validate_approvals_on_default_branch(approvals)
        return if approvals.approvals_left.to_i.zero? && approvals.approval_rules_left.empty?

        error('The merge request requires two approvals', <<~ERROR)
          This merge request is missing an approval. Please ensure
          its approved by a maintainer, and by an AppSec team member.
        ERROR
      end

      def validate_approval_on_stable_branch(approvals)
        return unless approvals.approved_by.empty?

        error('The merge request must be approved', <<~ERROR)
          This merge request is missing an approval. Please ensure it has maintainer approval.
        ERROR
      end

      def next_security_versions
        @next_security_versions ||= ReleaseTools::Versions
          .next_security_versions
      end

      # @param [String] summary
      # @param [String] details
      def error(summary, details)
        @errors << <<~HTML
          <details>
          <summary><strong>#{summary}</strong></summary>
          <br />

          #{details}

          </details>
        HTML
      end
    end
  end
end
