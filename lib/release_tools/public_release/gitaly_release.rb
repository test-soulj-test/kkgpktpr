# frozen_string_literal: true

module ReleaseTools
  module PublicRelease
    module GitalyRelease
      def update_versions
        logger.info(
          'Updating version files',
          project: project_path,
          version: version
        )

        ruby_version = <<~PROTO_VERSION
          # This file was auto-generated by the Release Tools project
          # (https://gitlab.com/gitlab-org/release-tools/), and should not be
          # modified.
          module Gitaly
            VERSION = '#{version}'
          end
        PROTO_VERSION

        commit_version_files(
          target_branch,
          {
            'VERSION' => version.to_s,
            'ruby/proto/gitaly/version.rb' => ruby_version
          },
          skip_ci: true
        )
      end

      def create_tag
        logger.info('Creating tag', tag: tag_name, project: project_path)

        # Gitaly requires tags to be annotated tags, so we must specify a tag
        # message.
        client.find_or_create_tag(
          project_path,
          tag_name,
          target_branch,
          message: "Version #{tag_name}"
        )
      end

      def add_release_metadata(tag)
        meta_version = version.to_normalized_version

        logger.info(
          'Recording release data',
          project: project_path,
          version: meta_version,
          tag: tag.name
        )

        release_metadata.add_release(
          name: 'gitaly',
          version: meta_version,
          sha: tag.commit.id,
          ref: tag.name,
          tag: true
        )
      end

      def project
        Project::Gitaly
      end
    end
  end
end