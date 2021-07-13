# frozen_string_literal: true

module ReleaseTools
  module Security
    # Toggle the Canonical to Security merge train based on mirror status
    #
    # When the built-in push mirroring is failing to mirror the main branch from
    # Canonical to Security, we want to fall back to our custom merge train in
    # order to keep development flowing.
    #
    # Once the mirroring has been resolved, we can toggle the merge train back
    # off until it's needed again.
    class MergeTrainService
      include ::SemanticLogger::Loggable

      # Map a project to the scheduled task handling its merge-train execution
      #
      # See https://ops.gitlab.net/gitlab-org/merge-train/-/pipeline_schedules
      PROJECTS = {
        Project::GitlabEe => 110,
        Project::OmnibusGitlab => 123
      }.freeze

      def execute
        PROJECTS.each do |project, schedule_id|
          required = merge_train_required?(project)
          active = merge_train_active?(schedule_id)

          # If these are the same, we've already achieved the desired result
          next if required == active

          toggle_merge_train(schedule_id, required)
        end
      end

      def merge_train_active?(schedule_id)
        GitlabOpsClient
          .pipeline_schedule(Project::MergeTrain.path, schedule_id)
          .active
      end

      def merge_train_required?(subject_project)
        mirror = GitlabClient.remote_mirrors(subject_project)
          .detect { |m| m.url.include?('gitlab-org/security') }

        if mirror.nil?
          logger.fatal('Unable to detect project security mirror', project: subject_project)
          return false
        end

        return false if mirror.last_error.blank?

        mirror.last_error
          .split("\n")
          .any? { |l| l.include?("refs/heads/#{subject_project.default_branch}") }
      rescue ::Gitlab::Error::Error => ex
        logger.warn(
          'Unable to get project mirror status',
          project: subject_project,
          error: ex.message
        )

        false
      end

      def toggle_merge_train(schedule_id, active)
        logger.info('Toggling the merge-train scheduled task', id: schedule_id, active: active)

        schedule = GitlabOpsClient.edit_pipeline_schedule(
          Project::MergeTrain.path,
          schedule_id,
          active: active
        )

        ReleaseTools::Slack::MergeTrainNotification.toggled(schedule)
      end
    end
  end
end
