# frozen_string_literal: true

module ReleaseTools
  module PublicRelease
    # A release of Omnibus GitLab using the API.
    class OmnibusGitlabRelease
      include Release

      attr_reader :version, :client, :release_metadata

      VERSION_FILE = 'VERSION'

      VERSION_FILES = [
        Project::Gitaly.version_file,
        Project::GitlabPages.version_file,
        Project::GitlabShell.version_file,
        Project::GitlabElasticsearchIndexer.version_file,
        Project::Kas.version_file
      ].freeze

      def initialize(
        version,
        client: GitlabClient,
        release_metadata: ReleaseMetadata.new,
        commit: nil
      )
        unless version.ee?
          raise ArgumentError, "#{version} is not an EE version"
        end

        @version = version
        @gitlab_version = Version.new(version.to_normalized_version)
        @client = client
        @release_metadata = release_metadata
        @commit = commit
      end

      def execute
        logger.info(
          'Starting release of Omnibus GitLab',
          ee_version: version,
          ce_version: version.to_ce
        )

        verify_version_file
        create_target_branch
        compile_changelog
        update_component_versions

        ce_tag = create_ce_tag
        ee_tag = create_ee_tag

        add_release_data_for_tags(ce_tag, ee_tag)
        notify_slack(project, version)
      end

      def verify_version_file
        path = ee_project_path
        branch = ee_stable_branch
        from_file = read_version(path, VERSION_FILE, branch)

        return if @gitlab_version == from_file

        raise "The VERSION file in #{path} on branch #{branch} specifies " \
          "version #{from_file}, but the GitLab version we are releasing " \
          "is version #{@gitlab_version}. These versions must be identical " \
          "before we can proceed"
      end

      def compile_changelog
        return if version.rc?

        logger.info('Compiling changelog', project: project_path)

        ChangelogCompiler
          .new(project_path, client: client)
          .compile(version, branch: target_branch)
      end

      def create_ce_tag
        tag = version.to_ce.tag

        logger.info('Creating CE tag', tag: tag, project: ce_project_path)
        find_or_create_tag(tag, ce_project_path, ce_stable_branch)
      end

      def create_ee_tag
        tag = tag_name

        logger.info('Creating EE tag', tag: tag, project: ee_project_path)
        find_or_create_tag(tag, ee_project_path, ee_stable_branch)
      end

      def find_or_create_tag(tag, gitlab_project, gitlab_branch)
        Retriable.with_context(:api) do
          client.tag(project_path, tag: tag)
        rescue Gitlab::Error::NotFound
          gitlab_version =
            read_version(gitlab_project, VERSION_FILE, gitlab_branch)

          update_version_file(gitlab_version)

          # Omnibus requires annotated tags to build packages, so we must
          # specify a message.
          client.create_tag(project_path, tag, target_branch, "Version #{tag}")
        end
      end

      # Updates the contents of all component versions (e.g.
      # GITALY_SERVER_VERSION) according to their contents in the GitLab EE
      # repository.
      def update_component_versions
        logger.info(
          'Updating component versions',
          project: project_path,
          branch: target_branch
        )

        version_files = VERSION_FILES

        # Prior to 13.10.0, Workhorse is still a separate component from the
        # Rails application.
        #
        # This check will be removed as part of
        # https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1628.
        if @gitlab_version.major <= 13 && @gitlab_version.minor < 10
          version_files = [Project::GitlabWorkhorse.version_file, *version_files]
        end

        branch = ee_stable_branch
        versions = version_files.each_with_object({}) do |file, hash|
          hash[file] = read_version(ee_project_path, file, branch).to_s
        end

        commit_version_files(
          target_branch,
          versions,
          message: 'Update component version files'
        )
      end

      def update_version_file(version)
        commit_version_files(
          target_branch,
          { VERSION_FILE => version },
          message: "Update #{VERSION_FILE} to #{version}"
        )
      end

      def add_release_data_for_tags(ce_tag, ee_tag)
        meta_version = version.to_normalized_version

        logger.info(
          'Recording release data',
          project: project_path,
          version: meta_version,
          ce_tag: ce_tag.name,
          ee_tag: ee_tag.name
        )

        release_metadata.add_release(
          name: 'omnibus-gitlab-ce',
          version: meta_version,
          sha: ce_tag.commit.id,
          ref: ce_tag.name,
          tag: true
        )

        release_metadata.add_release(
          name: 'omnibus-gitlab-ee',
          version: meta_version,
          sha: ee_tag.commit.id,
          ref: ee_tag.name,
          tag: true
        )
      end

      def read_version(project, name, branch)
        content = Retriable.with_context(:api) do
          client.file_contents(project, name, branch)
        end

        Version.new(content.strip)
      end

      def source_for_target_branch
        @commit || super
      end

      def project
        Project::OmnibusGitlab
      end

      def ce_project_path
        Project::GitlabCe.canonical_or_security_path
      end

      def ee_project_path
        Project::GitlabEe.canonical_or_security_path
      end

      def ee_stable_branch
        @gitlab_version.stable_branch(ee: true)
      end

      def ce_stable_branch
        @gitlab_version.stable_branch
      end
    end
  end
end
