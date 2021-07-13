# frozen_string_literal: true

module ReleaseTools
  module Tasks
    module AutoDeploy
      # CheckProduction verifies production status.
      #
      # It can authorize a deployment if DEPLOY_VERSION variable is set.
      # It can notify production status on slack if CHAT_CHANNEL is set.
      class CheckProduction
        include ::SemanticLogger::Loggable

        def execute
          manager = ReleaseTools::Promotion::Manager.new(
            pipeline_url: deployer_pipeline_url,
            skip_active_deployment_check: skip_active_deployment_check?
          )

          if chatops?
            logger.info("Checking production status", slack_channel: slack_channel)

            manager.check_status(slack_channel, raise_on_failure: raise_on_failure?)
          elsif production_issue_iid
            manager.production_issue_report(
              project: gitlab_production_project_path,
              issue_iid: production_issue_iid
            )
          elsif authorize?
            logger.info("Checking production promotion", deploy_version: deploy_version)

            manager.authorize!(omnibus_package_version, monthly_issue)
          elsif deployment_check?
            logger.info("Checking production deployment status", deploy_version: deploy_version, deployment_step: deployment_step, deployment_job_url: deployment_job_url)

            manager.deployment_check_report(omnibus_package_version, deployment_step, deployment_job_url)
          else
            raise 'This task requires one of the following environment variables. DEPLOY_VERSION: containing the package version to authorize, or CHAT_CHANNEL: the slack channel id for writing the check results'
          end
        end

        def monthly_issue
          monthly_version = ReleaseManagers::Schedule.new.active_version

          ReleaseTools::MonthlyIssue.new(version: monthly_version)
        end

        def omnibus_package_version
          ReleaseTools::Version.new(deploy_version)
        end

        def slack_channel
          ENV['CHAT_CHANNEL']
        end

        def deploy_version
          ENV.fetch('DEPLOY_VERSION') do
            ReleaseTools::AutoDeploy::Tag.new.omnibus_package if ReleaseTools::AutoDeploy.coordinator_pipeline?
          end
        end

        def chatops?
          slack_channel.present?
        end

        def authorize?
          deploy_version.present? && !deployment_check?
        end

        def deployment_check?
          ENV['DEPLOYMENT_CHECK'] == 'true'
        end

        # There are two situations where we want to avoid checking for an active (ongoing) production deployment:
        # - A caller of this trigger could set SKIP_DEPLOYMENT_CHECK to avoid the check, i.e. during feature flag activation
        # - When we are checking the status during an ongoing deployment (deployment_check? == true)
        def skip_active_deployment_check?
          ENV['SKIP_DEPLOYMENT_CHECK'] == 'true' || deployment_check?
        end

        private

        def deployment_step
          ENV['DEPLOYMENT_STEP']
        end

        def deployment_job_url
          ENV['DEPLOYER_JOB_URL']
        end

        def deployer_pipeline_url
          ENV.fetch('DEPLOYER_PIPELINE_URL', ENV['CI_PIPELINE_URL'])
        end

        def raise_on_failure?
          ENV['FAIL_IF_NOT_SAFE'] == 'true'
        end

        def production_issue_iid
          ENV['PRODUCTION_ISSUE_IID']
        end

        def gitlab_production_project_path
          ENV['GITLAB_PRODUCTION_PROJECT_PATH'] || Project::Infrastructure::Production
        end
      end
    end
  end
end
