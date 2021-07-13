# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    module Tagger
      class Coordinator
        include ::SemanticLogger::Loggable

        PROJECT = Project::ReleaseTools

        def tag!
          # Prevent an infinite loop
          return if AutoDeploy.coordinator_pipeline?

          logger.info('Creating Coordinator tag', name: tag_name)

          return if SharedStatus.dry_run?

          Retriable.with_context(:api) do
            client.create_tag(
              PROJECT,
              tag_name,
              PROJECT.default_branch,
              tag_message
            )
          end
        rescue ::Gitlab::Error::ResponseError => ex
          logger.fatal(
            'Failed to tag Coordinator',
            name: tag.name,
            target: PROJECT.default_branch,
            error_code: ex.response_status,
            error_message: ex.message
          )

          raise ex
        end

        def tag_name
          ReleaseTools::AutoDeploy::Tag.current
        end

        def tag_message
          "Created via #{ENV['CI_JOB_URL']}"
        end

        private

        def client
          ReleaseTools::GitlabOpsClient
        end
      end
    end
  end
end
