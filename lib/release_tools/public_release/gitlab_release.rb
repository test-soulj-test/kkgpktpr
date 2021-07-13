# frozen_string_literal: true

module ReleaseTools
  module PublicRelease
    # A release of GitLab CE and EE using the API.
    class GitlabRelease
      include Release

      attr_reader :version, :client, :release_metadata

      # The sleep intervals to use when waiting for the EE to CE sync.
      #
      # At 15 intervals of 60 seconds, we wait at most 15 minutes.
      #
      # As of June 2020, almost all sync pipelines finish in less than 6
      # minutes. As such, 15 minutes should be more than enough.
      WAIT_SYNC_INTERVALS = Array.new(15, 60)

      # The file to check when waiting for the EE to CE sync.
      SYNC_CHECK_FILE = 'CHANGELOG.md'

      # The name of the default branch for CE and EE.
      DEFAULT_BRANCH = Project::GitlabEe.default_branch

      # The name of the version file storing the CE/EE version.
      VERSION_FILE = 'VERSION'

      # Error raised when a EE to CE sync pipeline is still running.
      PipelineTooSlow = Class.new(StandardError) do
        def message
          'The EE to CE pipeline did not finish in a timely manner'
        end
      end

      # Error raised when a EE to CE sync pipeline failed.
      PipelineFailed = Class.new(StandardError) do
        def message
          'The EE to CE pipeline failed'
        end
      end

      def initialize(
        version,
        client: GitlabClient,
        release_metadata: ReleaseMetadata.new,
        commit: nil
      )
        @version = version.to_ee
        @client = client
        @release_metadata = release_metadata
        @commit = commit
      end

      def execute
        logger.info(
          'Starting release of GitLab CE and EE',
          ee_version: version,
          ce_version: version.to_ce
        )

        create_ce_target_branch
        create_ee_target_branch

        update_gitaly_server_version
        compile_changelogs
        update_versions

        # Now that EE has been updated, we need to wait for the Merge Train to
        # sync all changes from EE to CE. Not waiting for this could result in
        # us tagging outdated commits/code.
        wait_for_ee_to_ce_sync
        create_ce_commit_to_run_ci

        ce_tag = create_ce_tag
        ee_tag = create_ee_tag

        start_new_minor_release
        add_release_data_for_tags(ce_tag, ee_tag)

        notify_slack(Project::GitlabCe, version.to_ce)
        notify_slack(Project::GitlabEe, version)
      end

      def create_ce_target_branch
        # CE stable branches must be created before we can sync the EE changes
        # to them. Branching off from master would include commits we won't
        # actually release, which is confusing. Thus, we create the initial
        # branch from the last stable branch.
        source = Version.new(version.previous_minor).stable_branch

        logger.info(
          'Creating CE target branch',
          project: ce_project_path,
          source: source,
          branch: ce_target_branch
        )

        client.find_or_create_branch(ce_target_branch, source, ce_project_path)
      end

      def create_ee_target_branch
        source = source_for_target_branch

        logger.info(
          'Creating EE target branch',
          project: project_path,
          source: source,
          branch: target_branch
        )

        client.find_or_create_branch(
          target_branch,
          source,
          project_path
        )
      end

      def update_gitaly_server_version
        # When releasing an RC, there is no Gitaly stable branch yet (as Gitaly
        # RCs don't create stable branches). This means the
        # GITALY_SERVER_VERSION should stay as-is.
        return if version.rc?

        project = Project::Gitaly.canonical_or_security_path

        # Gitaly branches don't use the -ee suffix.
        branch = version.to_ce.stable_branch
        content = Retriable.with_context(:api) do
          client.file_contents(project, 'VERSION', branch).strip
        end

        # We skip CI tests here as we'll be comitting a few more files, making
        # pipelines being created at this point redundant.
        commit_version_files(
          target_branch,
          { Project::Gitaly.version_file => content },
          message: "Update Gitaly version to #{content}",
          skip_ci: true
        )
      end

      # Creates a Merge Train pipeline to sync EE to CE and waits for it to
      # complete.
      #
      # We can't rely on the state of one or more files to determine if CE is in
      # sync with EE, as these files (e.g. a changelog) may not change when
      # operations are retried. This would result in this code thinking CE and
      # EE are in sync, even when this may not be the case (e.g. not all code
      # has been synced yet).
      #
      # To handle this, we create a Merge Train pipeline ourselves and wait for
      # it to finish. In some cases code may have already been synced, but this
      # approach is the only way we can guarantee that CE and EE are in sync.
      def wait_for_ee_to_ce_sync
        return if Feature.enabled?(:skip_foss_merge_train)

        logger.info('Creating pipeline to sync EE to CE', project: project_path)

        initial_pipeline = GitlabOpsClient.client.create_pipeline(
          Project::MergeTrain.path,
          Project::MergeTrain.default_branch,
          MERGE_FOSS: '1',
          SOURCE_PROJECT: project_path,
          SOURCE_BRANCH: target_branch,
          TARGET_PROJECT: ce_project_path,
          TARGET_BRANCH: ce_target_branch
        )

        url = initial_pipeline.web_url

        logger.info('Created pipeline to sync EE to CE', pipeline: url)

        Retriable.retriable(intervals: WAIT_SYNC_INTERVALS, on: PipelineTooSlow) do
          pipeline = GitlabOpsClient
            .pipeline(Project::MergeTrain.path, initial_pipeline.id)

          case pipeline.status
          when 'success'
            logger.info('The EE to CE sync finished', pipeline: url)
            return
          when 'running', 'pending', 'created'
            logger.info('The EE to CE sync is still running', pipeline: url)
            raise PipelineTooSlow
          else
            logger.error(
              'The EE to CE sync did not succeed',
              pipeline: url,
              status: pipeline.status
            )

            raise PipelineFailed
          end
        end
      end

      def create_ce_commit_to_run_ci
        # When bumping versions on CE, we skip pipelines for the version
        # commits. We then sync the EE changes to CE.
        #
        # If there are no changes to sync to CE and we tag the latest commit,
        # that tag will point to a commit with `ci skip`; preventing pipelines
        # from running.
        #
        # To handle this, we check if the latest commit skips pipelines. If so,
        # we create a dummy commit.
        #
        # This should only happen rarely, as most of the time the Merge Train
        # _will_ have changes to sync.
        path = ce_project_path
        ref = ce_target_branch
        commit = client.commit(path, ref: ref)

        return unless commit.message.include?('[ci skip]')

        message = <<~MSG.strip
          Ensure pipelines run for #{version.to_ce}

          The last commit synced to this repository includes the "ci skip" tag,
          preventing tag pipelines from running. To ensure these pipelines do run,
          we create this commit. This normally is only necessary if a Merge Train
          sync didn't introduce any new changes.

          For more information, refer to issue
          https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1355.
        MSG

        # When committing changes using the API, at least one action must be
        # present. However, it's fine if that action doesn't actually change
        # anything. Thus, to create a commit we update the VERSION file to what
        # it's already set to, creating an empty commit in the process that
        # allows tags to trigger a pipeline.
        client.create_commit(
          path,
          ref,
          message,
          [
            {
              action: 'update',
              file_path: 'VERSION',
              content: version.to_ce.to_s
            }
          ]
        )
      end

      def compile_changelogs
        return if version.rc?

        logger.info('Compiling changelog', project: project_path)

        ChangelogCompiler
          .new(project_path, client: client)
          .compile(version, branch: target_branch)
      end

      def update_versions
        logger.info(
          'Updating EE version file',
          project: project_path,
          version: version,
          branch: target_branch
        )

        # On EE this will be the last commit on the stable branch. To ensure
        # tagging pipelines run, we _don't_ skip any CI pipelines here. We
        # explicily set `skip_ci: false` so that it doesn't look like we just
        # forgot to set it at all.
        #
        # For CE it's fine to skip, because we will create a commit to sync EE
        # changes to CE.
        commit_version_files(
          target_branch,
          { VERSION_FILE => version.to_s },
          skip_ci: false,
          skip_merge_train: true
        )

        logger.info(
          'Updating CE version file',
          project: ce_project_path,
          version: version,
          branch: ce_target_branch
        )

        commit_version_files(
          ce_target_branch,
          { VERSION_FILE => version.to_ce.to_s },
          project: ce_project_path,
          skip_ci: true
        )
      end

      def start_new_minor_release
        return unless version.monthly?

        ee_pre = version.to_upcoming_pre_release
        ce_pre = version.to_ce.to_upcoming_pre_release

        logger.info(
          'Starting a new EE pre-release',
          project: project_path,
          version: ee_pre,
          branch: DEFAULT_BRANCH
        )

        commit_version_files(
          DEFAULT_BRANCH,
          { VERSION_FILE => ee_pre },
          skip_ci: true
        )

        logger.info(
          'Starting a new CE pre-release',
          project: ce_project_path,
          version: ce_pre,
          branch: DEFAULT_BRANCH
        )

        commit_version_files(
          DEFAULT_BRANCH,
          { VERSION_FILE => ce_pre },
          project: ce_project_path,
          skip_ci: true
        )
      end

      def create_ee_tag
        tag = version.tag

        logger.info('Creating EE tag', tag: tag, project: project_path)

        client.find_or_create_tag(
          project_path,
          tag,
          target_branch,
          message: "Version #{tag}"
        )
      end

      def create_ce_tag
        tag = version.to_ce.tag

        logger.info('Creating CE tag', tag: tag, project: ce_project_path)

        client.find_or_create_tag(
          ce_project_path,
          tag,
          ce_target_branch,
          message: "Version #{tag}"
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
          name: 'gitlab-ee',
          version: meta_version,
          sha: ee_tag.commit.id,
          ref: ee_tag.name,
          tag: true
        )

        release_metadata.add_release(
          name: 'gitlab-ce',
          version: meta_version,
          sha: ce_tag.commit.id,
          ref: ce_tag.name,
          tag: true
        )
      end

      def source_for_target_branch
        @commit || super
      end

      def project
        Project::GitlabEe
      end

      def ce_target_branch
        version.to_ce.stable_branch
      end

      def ce_project_path
        Project::GitlabCe.canonical_or_security_path
      end
    end
  end
end
