# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    module Tagger
      class Omnibus
        include ::SemanticLogger::Loggable
        include ReleaseMetadataTracking

        PROJECT = Project::OmnibusGitlab

        TAG_FORMAT = '%<release_tag>s+%<gitlab_ref>.11s.%<packager_ref>.11s'

        attr_reader :version_map, :target_branch, :release_metadata

        def initialize(target_branch, version_map, release_metadata = ReleaseMetadata.new)
          @target_branch = target_branch
          @version_map = version_map
          @release_metadata = release_metadata
        end

        def tag_name
          @tag_name ||= format(
            TAG_FORMAT,
            release_tag: AutoDeploy::Tag.current,
            gitlab_ref: gitlab_ref,
            packager_ref: packager_ref
          )
        end

        def tag_message
          @tag_message ||=
            begin
              tag_message = +"Auto-deploy Omnibus #{tag_name}\n\n"
              tag_message << @version_map
                .map { |component, version| "#{component}: #{version}" }
                .join("\n")
            end
        end

        def tag!
          return unless AutoDeploy.coordinator_pipeline?

          logger.info('Creating Omnibus tag', name: tag_name, target: branch_head.id)

          add_release_data

          return if SharedStatus.dry_run?

          GitlabClient.create_tag(
            PROJECT.auto_deploy_path,
            tag_name,
            packager_ref,
            tag_message
          )
        rescue ::Gitlab::Error::Error => ex
          logger.fatal(
            "Failed to tag Omnibus",
            name: tag_name,
            target: branch_head.id,
            error_code: ex.response_status,
            error_message: ex.message
          )
        end

        private

        def branch_head
          @branch_head ||= GitlabClient.commit(PROJECT.auto_deploy_path, ref: @target_branch)
        end

        def packager_name
          'omnibus-gitlab-ee'
        end

        def gitlab_ref
          @version_map.fetch('VERSION')
        end

        def packager_ref
          branch_head.id
        end
      end
    end
  end
end
