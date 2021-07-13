# frozen_string_literal: true

module ReleaseTools
  module PublicRelease
    # A release of Gitaly from the `master` branch, using the API.
    #
    # The code for a default branch release is separate to ensure we don't
    # accidentally run the wrong kind of code for a release. For example,
    # mixing this code with the code for a monthly release could result in
    # monthly release related code running for a default branch release, even
    # when not desired.
    class GitalyMasterRelease
      include Release
      include GitalyRelease

      attr_reader :version, :client, :release_metadata

      def initialize(
        version,
        client: GitlabClient,
        release_metadata: ReleaseMetadata.new
      )
        unless version.rc?
          raise(
            ArgumentError,
            'Releasing Gitaly from the default branch requires an RC version'
          )
        end

        @version = version.to_ce
        @client = client
        @release_metadata = release_metadata
      end

      def execute
        logger.info(
          'Starting release of Gitaly from the default branch',
          version: version
        )

        update_versions

        tag = create_tag

        add_release_metadata(tag)
        notify_slack(project, version)
      end

      def target_branch
        Project::Gitaly.default_branch
      end
    end
  end
end
