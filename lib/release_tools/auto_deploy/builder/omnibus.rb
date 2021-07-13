# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    module Builder
      class Omnibus
        include ::SemanticLogger::Loggable

        PROJECT = ReleaseTools::Project::OmnibusGitlab

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
          @version_map = ReleaseTools::ComponentVersions.for_omnibus(@commit_id)

          changes = false

          if component_changes?
            commit
            changes ||= true
          else
            logger.warn('No changes to Omnibus component versions')
          end

          if builder_changes?
            tag
            changes ||= true
          else
            logger.warn('No changes to Omnibus, nothing to tag')
          end

          changes
        end

        private

        # Check if the versions defined by gitlab-rails are now differing from
        # those defined by Omnibus
        def component_changes?
          @version_map.any? do |filename, current|
            GitlabClient.file_contents(
              PROJECT.auto_deploy_path,
              filename,
              @target_name
            ).chomp != current
          end
        rescue ::Gitlab::Error::ResponseError => ex
          logger.warn(
            'Failed to find Omnibus version file',
            target: @target_name,
            error_code: ex.response_status,
            error_message: ex.message
          )

          false
        end

        # Check if the builder itself has changes on the target branch
        def builder_changes?
          refs = GitlabClient.commit_refs(PROJECT.auto_deploy_path, @target_branch)

          # When our target branch has no associated tags, then there have been
          # changes on the branch since we last tagged it, and should be
          # considered changed
          refs.none? { |ref| ref.type == 'tag' }
        end

        def commit
          return if SharedStatus.dry_run?
          return unless AutoDeploy.coordinator_pipeline?

          actions = @version_map.map do |filename, contents|
            {
              action: 'update',
              file_path: "/#{filename}",
              content: "#{contents.strip}\n"
            }
          end

          commit = Retriable.with_context(:api) do
            GitlabClient.create_commit(
              PROJECT.auto_deploy_path,
              @target_name,
              'Update component versions',
              actions
            )
          end

          logger.info('Updated Omnibus versions', url: commit.web_url)

          commit
        rescue ::Gitlab::Error::ResponseError => ex
          logger.warn(
            'Failed to commit Omnibus version changes',
            target: @target_name,
            error_code: ex.response_status,
            error_message: ex.message
          )

          raise ex
        end

        def tag
          Tagger::Omnibus
            .new(@target_branch, @version_map, @release_metadata)
            .tag!
        end
      end
    end
  end
end
