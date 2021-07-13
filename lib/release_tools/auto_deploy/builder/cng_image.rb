# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    module Builder
      class CNGImage
        include ::SemanticLogger::Loggable

        PROJECT = ReleaseTools::Project::CNGImage
        VARIABLES_FILE = 'ci_files/variables.yml'

        attr_reader :version_map

        # target_branch - AutoDeploy::Branch object
        # commit_id - SHA of a passing gitlab-rails commit
        def initialize(target_branch, commit_id, release_metadata = ReleaseTools::ReleaseMetadata.new)
          @target_branch = target_branch
          @target_name = target_branch.to_s
          @commit_id = commit_id
          @release_metadata = release_metadata
        end

        # Update and tag the project, if necessary
        #
        # Returns true when changes were made or detected, false otherwise
        def execute
          @version_map = ReleaseTools::ComponentVersions.for_cng(@commit_id)

          current = current_variables
          changes = false

          if component_changes?(current)
            commit(current.merge(@version_map))
            changes ||= true
          else
            logger.warn('No changes to CNG component versions')
          end

          if builder_changes?
            tag
            changes ||= true
          else
            logger.warn('No changes to CNG, nothing to tag')
          end

          changes
        end

        private

        def component_changes?(current_variables)
          @version_map.any? do |component, version|
            current_variables[component] != version
          end
        end

        # Check if the builder itself has changes on the target branch
        def builder_changes?
          refs = GitlabClient.commit_refs(PROJECT.auto_deploy_path, @target_branch)

          # When our target branch has no associated tags, then there have been
          # changes on the branch since we last tagged it, and should be
          # considered changed
          refs.none? { |ref| ref.type == 'tag' }
        end

        def commit(new_variables)
          return if SharedStatus.dry_run?
          return unless AutoDeploy.coordinator_pipeline?

          action = {
            action: 'update',
            file_path: VARIABLES_FILE,
            content: { 'variables' => new_variables }.to_yaml
          }

          commit = Retriable.with_context(:api) do
            GitlabClient.create_commit(
              PROJECT.auto_deploy_path,
              @target_name,
              'Update component versions',
              [action]
            )
          end

          logger.info('Updated CNG versions', url: commit.web_url)

          commit
        rescue ::Gitlab::Error::ResponseError => ex
          logger.warn(
            'Failed to commit CNG version changes',
            target: @target_name,
            error_code: ex.response_status,
            error_message: ex.response_message
          )

          raise ex
        end

        def tag
          Tagger::CNGImage
            .new(@target_branch, @version_map, @release_metadata)
            .tag!
        end

        def current_variables
          Retriable.with_context(:api) do
            variables = GitlabClient.file_contents(
              PROJECT.auto_deploy_path,
              VARIABLES_FILE,
              @target_name
            ).chomp

            YAML.safe_load(variables).fetch('variables')
          end
        rescue ::Gitlab::Error::ResponseError => ex
          logger.warn(
            'Failed to load current CNG variables',
            target: @target_name,
            error: ex.message
          )

          raise ex
        end
      end
    end
  end
end
