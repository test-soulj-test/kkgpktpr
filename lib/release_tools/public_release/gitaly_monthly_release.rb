# frozen_string_literal: true

module ReleaseTools
  module PublicRelease
    # A monhtly release of Gitaly using the API.
    #
    # This class is only concerned with monthly releases. If a release from the
    # `master` branch needs to be created, use `GitalyMasterRelease` instead.
    class GitalyMonthlyRelease
      include Release
      include GitalyRelease

      attr_reader :version, :client, :release_metadata

      def initialize(
        version,
        client: GitlabClient,
        release_metadata: ReleaseMetadata.new,
        commit: nil
      )
        @version = version.to_ce
        @client = client
        @release_metadata = release_metadata
        @commit = commit
      end

      def execute
        logger.info('Starting release of Gitaly', version: version)

        create_target_branch
        compile_changelog
        update_versions

        tag = create_tag

        add_release_metadata(tag)
        notify_slack(project, version)
      end

      def compile_changelog
        return if version.rc?

        logger.info('Compiling changelog', project: project_path)

        ChangelogCompiler
          .new(project_path, client: client)
          .compile(version, branch: target_branch)
      end

      def source_for_target_branch
        @commit || super
      end

      def ee_project_path
        Project::GitlabEe.canonical_or_security_path
      end

      def ce_project_path
        Project::GitlabCe.canonical_or_security_path
      end
    end
  end
end
