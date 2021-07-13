# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    module Tagger
      class CNGImage
        include ::SemanticLogger::Loggable
        include ReleaseMetadataTracking

        PROJECT = Project::CNGImage

        TAG_FORMAT = '%<release_tag>s+%<gitlab_ref>.11s'

        attr_reader :version_map, :target_branch, :release_metadata

        def initialize(target_branch, version_map, release_metadata = ReleaseMetadata.new)
          @target_branch = target_branch
          @version_map = version_map
          @release_metadata = release_metadata
          @helm_tagger = ReleaseTools::AutoDeploy::Tagger::Helm
            .new(@target_branch.to_s, @version_map)
        end

        def tag_name
          @tag_name ||= format(
            TAG_FORMAT,
            release_tag: AutoDeploy::Tag.current,
            gitlab_ref: gitlab_ref
          )
        end

        def tag_message
          @tag_message ||=
            begin
              tag_message = +"Auto-deploy CNG #{tag_name}\n\n"
              tag_message << @version_map
                .map { |component, version| "#{component}: #{version}" }
                .join("\n")
            end
        end

        def tag!
          return unless AutoDeploy.coordinator_pipeline?

          logger.info('Creating CNG tag', name: tag_name, target: branch_head.id)

          add_release_data

          return if SharedStatus.dry_run?

          tag = GitlabClient.create_tag(
            PROJECT.auto_deploy_path,
            tag_name,
            branch_head.id,
            tag_message
          )

          @helm_tagger.tag!(tag_name)

          tag
        rescue ::Gitlab::Error::Error => ex
          logger.fatal(
            "Failed to tag CNG",
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
          'cng-ee'
        end

        def gitlab_ref
          @version_map.fetch('GITLAB_VERSION')
        end

        def packager_ref
          branch_head.id
        end
      end
    end
  end
end
