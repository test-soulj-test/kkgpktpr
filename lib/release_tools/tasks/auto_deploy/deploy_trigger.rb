# frozen_string_literal: true

# Triggers a deployment to a specific environment using
# the specified deployer branch
module ReleaseTools
  module Tasks
    module AutoDeploy
      class DeployTrigger
        include ::SemanticLogger::Loggable

        PROJECT = ReleaseTools::Project::Deployer
        DEPLOY_USER = 'deployer'

        # environment - The environment to deploy to,
        #   it can be one (e.g 'gstg') or a combination
        #   of them (e.g 'gprd-cny,gprd').
        # ref - Deployer branch to use to. Options available:
        #   * 'master' - Triggers a deployment.
        #   * 'next-gen' - Triggers a deployment in dry-run mode
        #   (to be removed)
        def initialize(environment:, ref:)
          @environment = environment
          @ref = ref
        end

        def execute
          logger.debug('Triggering deployment', environment: @environment, ref: @ref, variables: variables)

          return if SharedStatus.dry_run?

          trigger = GitlabOpsClient.run_trigger(
            PROJECT.ops_path,
            token,
            @ref,
            variables
          )

          logger.info('Triggered deployer pipeline', url: trigger.web_url)

          save_pipeline_id_to_deploy_vars(trigger.id)
        rescue ::Gitlab::Error::Error => ex
          logger.fatal(
            'Failed to trigger a deployer pipeline',
            version: omnibus_package,
            error_code: ex.response_status,
            error_message: ex.message
          )

          raise
        end

        private

        # Allow a defined trigger token, falling back to the job token
        def token
          ENV.fetch('DEPLOYER_TRIGGER_TOKEN') do |token_a|
            ENV.fetch('CI_JOB_TOKEN') do |token_b|
              raise "Missing `#{token_a}` or `#{token_b}` variable"
            end
          end
        end

        def variables
          {
            'DEPLOY_ENVIRONMENT' => @environment,
            'DEPLOY_USER' => DEPLOY_USER,
            'DEPLOY_VERSION' => omnibus_package,
            'SKIP_JOB_ON_COORDINATOR_PIPELINE' => 'true'
          }
        end

        def omnibus_package
          @omnibus_package ||= ReleaseTools::AutoDeploy::Tag.new.omnibus_package
        end

        def save_pipeline_id_to_deploy_vars(pipeline_id)
          logger.info('Updating deploy_vars', pipeline_id: pipeline_id)

          File.open('deploy_vars.env', 'w') do |deploy_vars|
            deploy_vars.write("DEPLOY_PIPELINE_ID=#{pipeline_id}")
          end
        end
      end
    end
  end
end
