# frozen_string_literal: true

module ReleaseTools
  module PublicRelease
    # A release of our CNG image using the API.
    class CNGImageRelease
      include Release

      attr_reader :version, :client, :release_metadata

      DEFAULT_UBI_VERSION = '8'

      VERSION_FILES = [
        Project::Gitaly.version_file,
        Project::GitlabShell.version_file,
        Project::GitlabPages.version_file,
        Project::GitlabElasticsearchIndexer.version_file
      ].freeze

      GITLAB_VERSION_FILES =
        %w[GITLAB_VERSION GITLAB_REF_SLUG GITLAB_ASSETS_TAG].freeze

      VARIABLES_FILE = 'ci_files/variables.yml'

      def initialize(
        version,
        client: GitlabClient,
        release_metadata: ReleaseMetadata.new,
        ubi_version: DEFAULT_UBI_VERSION,
        commit: nil
      )
        @version = version.to_ee
        @gitlab_version = Version.new(@version.to_normalized_version)
        @client = client
        @release_metadata = release_metadata
        @ubi_version = ubi_version
        @commit = commit
      end

      def execute
        logger.info('Starting release of CNG', version: version)

        create_target_branch

        ce_tag, ee_tag, ubi_tag = update_component_versions

        add_release_data_for_tags(ce_tag, ee_tag, ubi_tag)
        notify_slack(project, version)
      end

      def update_component_versions
        logger.info(
          'Updating component versions',
          project: project_path,
          branch: target_branch
        )

        ce_data, ee_data = distribution_component_versions

        [
          create_ce_tag(ce_data),
          create_ee_tag(ee_data),
          create_ubi_tag
        ]
      end

      def create_ce_tag(variables)
        find_or_create_tag(version.to_ce.tag, variables)
      end

      def create_ee_tag(variables)
        find_or_create_tag(version.to_ee.tag, variables)
      end

      def create_ubi_tag
        tag = version.tag(ee: true).gsub(/-ee$/, "-ubi#{@ubi_version}")

        logger.info('Creating UBI tag', tag: tag, project: project_path)

        # UBI tags contain the same data as EE, so we don't need to bump any
        # version files.
        client.find_or_create_tag(
          project_path,
          tag,
          target_branch,
          message: "Version #{tag}"
        )
      end

      def find_or_create_tag(tag, variables)
        Retriable.with_context(:api) do
          client.tag(project_path, tag: tag)
        rescue Gitlab::Error::NotFound
          logger.info('Creating new tag', tag: tag, project: project_path)

          commit_version_files(
            target_branch,
            VARIABLES_FILE => YAML.dump(variables)
          )

          client.create_tag(project_path, tag, target_branch, "Version #{tag}")
        end
      end

      def distribution_component_versions
        variables_yaml = read_file(VARIABLES_FILE)
        versions = component_versions
        ce_data = YAML.safe_load(variables_yaml)
        ee_data = YAML.safe_load(variables_yaml)

        ce_data['variables'].merge!(versions)
        ee_data['variables'].merge!(versions)

        # For the version of GitLab itself, we only want the -ee suffix for an
        # EE CNG release.
        GITLAB_VERSION_FILES.each do |file|
          ce_data['variables'][file] = @gitlab_version.tag(ee: false)
          ee_data['variables'][file] = @gitlab_version.tag(ee: true)
        end

        [ce_data, ee_data]
      end

      def component_versions
        gemfile_parser = GemfileParser.new(read_ee_file('Gemfile.lock'))
        components = {}
        version_files = VERSION_FILES

        # Prior to 13.10.0, Workhorse is still a separate component from the
        # Rails application.
        #
        # This check will be removed as part of
        # https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1628.
        if @gitlab_version.major <= 13 && @gitlab_version.minor < 10
          version_files = [Project::GitlabWorkhorse.version_file, *version_files]
        end

        version_files.each do |file|
          components[file] = version_string(read_ee_file(file))
        end

        Project::GitlabEe.gems.each do |pattern, file|
          components[file] = gemfile_parser.gem_version(pattern)
        end

        components
      end

      def add_release_data_for_tags(ce_tag, ee_tag, ubi_tag)
        meta_version = version.to_normalized_version

        logger.info(
          'Recording release data',
          project: project_path,
          version: meta_version,
          ce_tag: ce_tag.name,
          ee_tag: ee_tag.name,
          ubi_tag: ubi_tag.name
        )

        add_release_data('cng-ce', meta_version, ce_tag)
        add_release_data('cng-ee', meta_version, ee_tag)
        add_release_data('cng-ee-ubi', meta_version, ubi_tag)
      end

      def add_release_data(name, version, tag)
        release_metadata.add_release(
          name: name,
          version: version,
          sha: tag.commit.id,
          ref: tag.name,
          tag: true
        )
      end

      def read_ee_file(file)
        path = Project::GitlabEe.canonical_or_security_path
        branch = @gitlab_version.stable_branch(ee: true)

        read_file(file, path, branch)
      end

      def read_file(file, project = project_path, branch = target_branch)
        content = Retriable.with_context(:api) do
          client.file_contents(project, file, branch)
        end

        content.strip
      end

      def version_string(version)
        if version.include?('.')
          "v#{version}"
        else
          version
        end
      end

      def project
        Project::CNGImage
      end

      def source_for_target_branch
        @commit || project.default_branch
      end
    end
  end
end
