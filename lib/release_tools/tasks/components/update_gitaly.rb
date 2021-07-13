# frozen_string_literal: true

module ReleaseTools
  module Tasks
    module Components
      class UpdateGitaly
        include Helper
        include ::SemanticLogger::Loggable

        TARGET_PROJECT = Services::UpdateComponentService::TARGET_PROJECT

        def initialize
          @gitlab_bot_token = ENV.fetch('GITLAB_BOT_PRODUCTION_TOKEN')
        end

        def execute
          if !changed?
            logger.info('Gitaly already up to date')
          elsif merge_request.exists?
            logger.info('Found existing merge request', merge_request: merge_request.url)

            notify_stale_merge_request if merge_request.notifiable?
          else
            logger.info('Creating merge request to update Gitaly')

            create_merge_request
          end
        end

        def notify_stale_merge_request
          logger.warn('Existing merge request is stale, issuing warning')

          return if SharedStatus.dry_run?

          Slack::AutoDeployNotification.on_stale_gitaly_merge_request(merge_request)

          merge_request.mark_as_stale
        end

        def create_merge_request
          ensure_source_branch_exists

          create_or_show_merge_request(merge_request)

          logger.info('Updating gitaly version')
          Services::UpdateComponentService
            .new(Project::Gitaly, source_branch_name)
            .execute

          merge_when_pipeline_succeeds
        end

        def source_branch_name
          'release-tools/update-gitaly'
        end

        def ensure_source_branch_exists
          logger.info('Making sure source branch exists', source_branch: source_branch_name)
          return if SharedStatus.dry_run?

          GitlabClient.find_or_create_branch(source_branch_name, TARGET_PROJECT.default_branch, TARGET_PROJECT)
        end

        def changed?
          Services::UpdateComponentService.new(Project::Gitaly, Project::Gitaly.default_branch).changed?
        end

        def merge_request
          @merge_request ||= UpdateGitalyMergeRequest.new(source_branch: source_branch_name)
        end

        def merge_when_pipeline_succeeds
          logger
            .info('Accepting merge request', merge_request: merge_request.url)

          # Approving the merge request can't be done by the author, so for
          # approving and merging we use gitlab-bot instead of the release-tools
          # bot.
          Services::MergeWhenPipelineSucceedsService
            .new(merge_request, token: @gitlab_bot_token)
            .execute
        end
      end
    end
  end
end
