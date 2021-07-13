# frozen_string_literal: true

module ReleaseTools
  module PublicRelease
    # A release of Helm using the API.
    class HelmGitlabRelease
      include Release

      attr_reader :version, :client, :release_metadata, :gitlab_version

      # The Markdown file that maps Helm versions to GitLab versions.
      VERSION_MAPPING_FILE = 'doc/installation/version_mappings.md'

      # The name of the file containing the Chart information.
      CHART_FILE = 'Chart.yaml'

      # The default branch of the charts project.
      DEFAULT_BRANCH = Project::HelmGitlab.default_branch

      # The charts that we manage, and the source of their appVersion fields.
      #
      # The keys are the names of the directories the chart files reside in. The
      # directory "." is used for the top-level chart file.
      #
      # The following values are available:
      #
      # * `:gitlab_version`: appVersion will be populated with the GitLab Rails
      #    version.
      # * `:unmanaged`: appVersion is left as-is, and only the charts version is
      #    updated. This is useful for components where appVersion is managed
      #    separate from Release Tools.
      # * `:gem_version`: appVersion is set to the Gem version as found in
      #   Gemfile.lock in the EE repository.
      # * a `String`: the path/name of the VERSION file to read in the GitLab EE
      #   repository. The contents of this file will be used to populate the
      #   appVersion field.
      CHART_APP_VERSION_SOURCES = {
        '.' => :gitlab_version,
        'geo-logcursor' => :gitlab_version,
        'gitlab-grafana' => :gitlab_version,
        'migrations' => :gitlab_version,
        'operator' => :gitlab_version,
        'sidekiq' => :gitlab_version,
        'task-runner' => :gitlab_version,
        'webservice' => :gitlab_version,
        'mailroom' => :gem_version,
        'gitlab-exporter' => :unmanaged,
        'gitaly' => Project::Gitaly.version_file,
        'gitlab-shell' => Project::GitlabShell.version_file,
        'kas' => Project::Kas.version_file,
        'praefect' => Project::Gitaly.version_file,
        'gitlab-pages' => Project::GitlabPages.version_file
      }.freeze

      def initialize(
        version,
        gitlab_version,
        client: GitlabClient,
        release_metadata: ReleaseMetadata.new,
        commit: nil
      )
        @version = version
        @gitlab_version = gitlab_version.to_ee
        @client = client
        @release_metadata = release_metadata
        @commit = commit
      end

      def execute
        if gitlab_version.rc?
          logger.info(
            'Not releasing Helm for an RC',
            version: version,
            gitlab_version: gitlab_version
          )

          return
        end

        logger.info(
          'Starting release of Helm',
          version: version,
          gitlab_version: gitlab_version
        )

        create_target_branch
        compile_changelog
        update_versions
        update_version_mapping

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

      def update_versions
        stable_charts = all_chart_files
        default_charts = all_chart_files(DEFAULT_BRANCH)

        # We validate first so we either update all charts, or none at all. This
        # way we notice unrecognised charts as early as possible.
        verify_chart_files(stable_charts)
        verify_chart_files(default_charts)

        update_chart_files(stable_charts)

        # On the default branch we need to only update the "version" field.
        update_default_chart_files(default_charts)
      end

      def verify_chart_files(files)
        files.each do |file|
          directory = File.dirname(file)
          name = File.basename(directory)

          next if CHART_APP_VERSION_SOURCES.key?(name)

          logger.error(
            'Aborting Helm release due to unrecognised chart directory',
            directory: directory
          )

          raise <<~ERROR
            The chart located at #{directory} is not recognised by Release Tools.

            You will have to add its directory name (#{name}) to the
            CHART_APP_VERSION_SOURCES constant in this file, with the correct
            source for its appVersion field. For example, if the chart uses
            the same appVersion as the GitLab Rails version, add the following
            entry:

              '#{name}' => :gitlab_version
          ERROR
        end
      end

      def update_chart_files(files)
        to_update = {}
        gemfile_parser = GemfileParser.new(read_ee_file('Gemfile.lock'))

        files.each do |file|
          name = File.basename(File.dirname(file))
          yaml = read_file(file)
          hash = YAML.safe_load(yaml)
          source = CHART_APP_VERSION_SOURCES[name]

          app_version =
            case source
            when :gitlab_version
              gitlab_version.to_normalized_version
            when :gem_version
              pattern = Project::GitlabEe::GEM_PATTERNS[name.to_sym]

              # Unrecognised Gems are an error, otherwise we may end up bumping
              # the chart versions incorrectly.
              unless pattern
                raise "No Gem name could be determined for Chart #{name}"
              end

              gemfile_parser.gem_version(pattern)
            when :unmanaged
              # If a chart's appVersion is unmanaged, we still want to update
              # the version field. So instead of using something like `next`, we
              # return `nil` and handle this below.
              nil
            else
              read_ee_file(source)
            end

          hash['appVersion'] = app_version if app_version
          hash['version'] = version.to_s
          to_update[file] = YAML.dump(hash)
        end

        commit_version_files(
          target_branch,
          to_update,
          message: version_files_commit_message
        )
      end

      def update_default_chart_files(files)
        to_update = {}

        files.each do |file|
          yaml = read_file(file, branch: DEFAULT_BRANCH)
          hash = YAML.safe_load(yaml)

          # We don't want to overwrite the version with an older one. For
          # example:
          #
          # * On the default branch the `version` field 2.0.0
          # * We are running a patch release for 1.5.0
          #
          # In a case like this, the `version` field is left as-is, instead of
          # being (incorrectly) set to 1.5.0.
          next unless version > Version.new(hash['version'])

          hash['version'] = version.to_s
          to_update[file] = YAML.dump(hash)
        end

        commit_version_files(
          DEFAULT_BRANCH,
          to_update,
          message: version_files_commit_message
        )
      end

      def update_version_mapping
        update_version_mapping_on_branch(target_branch)

        # For the default branch we can't reuse the Markdown of the target
        # branch, as both branches may have different content in these files.
        # For example, when running a patch release for an older version the
        # target branch won't have entries for newer versions.
        update_version_mapping_on_branch(DEFAULT_BRANCH)
      end

      def update_version_mapping_on_branch(branch)
        markdown = read_file(VERSION_MAPPING_FILE, branch: branch)
        mapping = Helm::VersionMapping.parse(markdown)

        mapping.add(version, gitlab_version)

        commit_version_files(
          branch,
          { VERSION_MAPPING_FILE => mapping.to_s },
          message: "Update version mapping for #{version}"
        )
      end

      def create_tag
        logger.info('Creating tag', tag: tag_name, project: project_path)

        client.find_or_create_tag(
          project_path,
          tag_name,
          target_branch,
          message: "Version #{tag_name} - contains GitLab EE #{gitlab_version.to_normalized_version}"
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
          name: 'helm-gitlab',
          version: meta_version,
          sha: tag.commit.id,
          ref: tag.name,
          tag: true
        )
      end

      def read_file(file, project: project_path, branch: target_branch)
        Retriable.with_context(:api) do
          client.file_contents(project, file, branch).strip
        end
      end

      def read_ee_file(file)
        project = Project::GitlabEe.canonical_or_security_path
        branch = gitlab_version.stable_branch(ee: true)

        read_file(file, project: project, branch: branch)
      end

      def all_chart_files(branch = target_branch)
        # We use a Set here so that if we retry the operation below, we don't
        # end up producing duplicate paths.
        paths = Set.new([CHART_FILE])

        Retriable.with_context(:api) do
          client
            .tree(
              project_path,
              ref: branch,
              path: 'charts/gitlab/charts',
              per_page: 100
            )
            .auto_paginate do |entry|
              paths << File.join(entry.path, CHART_FILE) if entry.type == 'tree'
            end
        end

        paths.to_a
      end

      def project
        Project::HelmGitlab
      end

      def source_for_target_branch
        @commit || DEFAULT_BRANCH
      end

      def version_files_commit_message
        "Update Chart versions to #{version}\n\n[ci skip]"
      end
    end
  end
end
