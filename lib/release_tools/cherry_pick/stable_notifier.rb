# frozen_string_literal: true

module ReleaseTools
  module CherryPick
    class StableNotifier
      attr_reader :version
      attr_reader :target

      def initialize(version, target:)
        @version = version
        @target = target
      end

      def comment(pick_result)
        if pick_result.success?
          successful_comment(pick_result)
        else
          failure_comment(pick_result)
        end
      end

      # Post a summary comment to the target with a list of picked and unpicked
      # merge requests
      #
      # picked   - Array of successful Results
      # unpicked - Array of failure Results
      def summary(picked, unpicked)
        return if version.monthly?
        return if picked.empty? && unpicked.empty?

        message = []

        if picked.any?
          message << <<~MSG
            Successfully picked the following merge requests:

            #{markdown_list(picked.collect(&:url))}
          MSG
        end

        if unpicked.any?
          message << <<~MSG
            Failed to pick the following merge requests:

            #{markdown_list(unpicked.collect(&:url))}
          MSG
        end

        create_merge_request_comment(target, message.join("\n"))
      end

      def blog_post_summary(picked)
        return if version.monthly? || version.rc?
        return if picked.empty?

        message = <<~MSG
          The following merge requests were picked into #{target.url}:

          ```
          #{markdown_list(picked.collect(&:to_markdown))}
          ```
        MSG

        create_issue_comment(target.release_issue, message)
      end

      private

      def markdown_list(array)
        array.map { |v| "* #{v}" }.join("\n")
      end

      def successful_comment(pick_result)
        comment = <<~MSG
          Automatically picked into #{target.pick_destination}, will merge into
          `#{version.stable_branch}` ready for `#{version}`.

          /unlabel #{PickIntoLabel.reference(version)}
        MSG

        create_merge_request_comment(pick_result.merge_request, comment)
      end

      def failure_comment(pick_result)
        comment = <<~MSG
          #{author_handle(pick_result.merge_request)} This merge request could
          not automatically be picked into `#{version.stable_branch}` for
          `#{version}` and will need manual intervention.

          Create a new merge request targeting the `#{target.branch_name}`
          branch in order to have this MR included in #{target.pick_destination}.

          Please follow the [Process for Developers](https://gitlab.com/gitlab-org/release/docs/blob/master/general/patch/process.md#process-for-developers).

          /unlabel #{PickIntoLabel.reference(version)}
        MSG

        create_merge_request_comment(pick_result.merge_request, comment)
      end

      def client
        GitlabClient
      end

      def create_issue_comment(issue, comment)
        if SharedStatus.dry_run?
          $stdout.puts "--> Adding the following comment to #{issue.project.path}##{issue.iid}:"
          $stdout.puts comment.indent(4)
          $stdout.puts
        else
          client.create_issue_note(
            issue.project,
            issue: issue,
            body: comment
          )
        end
      end

      def create_merge_request_comment(merge_request, comment)
        if SharedStatus.dry_run?
          $stdout.puts "--> Adding the following comment to #{merge_request.project_id}!#{merge_request.iid}:"
          $stdout.puts comment.indent(4)
          $stdout.puts
        else
          client.create_merge_request_comment(
            merge_request.project_id,
            merge_request.iid,
            comment
          )
        end
      end

      def author_handle(authorable)
        username = authorable&.author&.username

        "@#{username}" if username
      end
    end
  end
end
