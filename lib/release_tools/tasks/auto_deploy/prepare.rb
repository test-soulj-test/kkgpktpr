# frozen_string_literal: true

module ReleaseTools
  module Tasks
    module AutoDeploy
      class Prepare
        include ::SemanticLogger::Loggable

        def execute
          check_version

          prepare_monthly_release

          results = create_branches

          notify_results(results)
        end

        def prepare_monthly_release
          logger.info('Preparing the monthly release issue', version: version)
          Release::Prepare.new(version).execute
        end

        def create_branches
          logger.info('Creating the auto-deploy branches', branch: branch)
          ReleaseTools::Services::AutoDeployBranchService
            .new(branch)
            .create_branches!
        end

        def notify_results(results)
          logger.info('Notifying the operation results on slack')
          ReleaseTools::Slack::AutoDeployNotification.on_create(results)
        end

        def auto_deploy_naming
          @auto_deploy_naming ||= ReleaseTools::AutoDeploy::Naming.new
        end

        def branch
          @branch ||= auto_deploy_naming.branch
        end

        def version
          auto_deploy_naming.version
        end

        # Validates if the active version can be retrieved.
        #
        # A valid version is a hard requirement for this task,
        # in case it cannot be retrieved we should fail the task
        # with a meaningful error message
        #
        # @raise [RuntimeError] if `version` is nil
        def check_version
          return unless version.nil?

          logger.fatal('Cannot detect the active version')
          raise 'Cannot detect the active version'
        end
      end
    end
  end
end
