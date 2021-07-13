# frozen_string_literal: true

module ReleaseTools
  module CherryPick
    class AutoDeployNotifier
      attr_reader :branch_name, :project

      def initialize(branch_name, project)
        @branch_name = branch_name
        @project = project
      end

      def comment(pick_result)
        comment =
          if pick_result.success?
            successful_comment(pick_result)
          elsif pick_result.denied?
            denial_comment(pick_result)
          else
            failure_comment(pick_result)
          end

        create_merge_request_comment(pick_result.merge_request, comment)
      end

      def successful_comment(_pick_result)
        <<~MSG
          Successfully picked into #{branch_link}. This merge request will
          receive additional notifications as it's deployed.

          /unlabel #{PickIntoLabel.reference(:auto_deploy)}
        MSG
      end

      def denial_comment(pick_result)
        <<~MSG
          #{author_handle(pick_result.merge_request)} This merge request failed
          to be picked into #{branch_link} and will need manual intervention.

          * #{pick_result.reason}

          Please refer to [GitLab.com releases](https://about.gitlab.com/handbook/engineering/releases/#gitlabcom-releases-2).

          /unlabel #{PickIntoLabel.reference(:auto_deploy)}
        MSG
      end

      def failure_comment(pick_result)
        <<~MSG
          #{author_handle(pick_result.merge_request)} This merge request failed
          to be picked into #{branch_link} and will need manual intervention.

          Create a new merge request targeting #{branch_link}, resolve any
          conflicts, and assign it to a release manager for merging directly
          into the auto-deploy branch.

          /unlabel #{PickIntoLabel.reference(:auto_deploy)}
        MSG
      end

      def branch_link
        "[`#{branch_name}`](https://gitlab.com/#{project.security_path}/commits/#{branch_name})"
      end

      private

      def create_merge_request_comment(merge_request, comment)
        if SharedStatus.dry_run?
          $stdout.puts "--> Adding the following comment to #{merge_request.project_id}!#{merge_request.iid}:"
          $stdout.puts comment.indent(4)
          $stdout.puts
        else
          GitlabClient.create_merge_request_comment(
            merge_request.project_id,
            merge_request.iid,
            comment
          )
        end
      end

      def author_handle(merge_request)
        username = merge_request&.author&.username

        "@#{username}" if username
      end
    end
  end
end
