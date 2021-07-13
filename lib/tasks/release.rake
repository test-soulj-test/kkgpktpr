namespace :release do
  desc 'Create a release task issue'
  task :issue, [:version] do |_t, args|
    version = get_version(args)

    ReleaseTools::Tasks::Release::Issue.new(version).execute
  end

  desc 'Merges valid merge requests into preparation branches'
  task :merge, [:version] do |_t, args|
    pick = lambda do |project, version|
      target = ReleaseTools::PreparationMergeRequest
        .new(project: project, version: version)

      ReleaseTools.logger.info(
        'Picking into preparation merge requests',
        project: project,
        version: version,
        target: target.branch_name
      )

      ReleaseTools::CherryPick::StableService
        .new(project, version, target)
        .execute
    end

    version = get_version(args).to_ee

    pick[ReleaseTools::Project::GitlabEe, version]
    pick[ReleaseTools::Project::OmnibusGitlab, version.to_ce]
  end

  desc 'Prepare for a new release'
  task :prepare, [:version] do |_t, args|
    version = get_version(args)

    ReleaseTools::Tasks::Release::Prepare.new(version).execute
  end

  desc 'Create a QA issue'
  task :qa, [:from, :to] do |_t, args|
    version = get_version(version: args[:to].delete_prefix('v'))

    build_qa_issue(version, args[:from], args[:to])
  end

  desc "Check a release's build status"
  task :status, [:version] do |t, args|
    version = get_version(args)

    status = ReleaseTools::BranchStatus.for([version])

    status.each_pair do |project, results|
      results.each do |result|
        ReleaseTools.logger.tagged(t.name) do
          ReleaseTools.logger.info(project, result.to_h)
        end
      end
    end

    ReleaseTools::Slack::ChatopsNotification.branch_status(status)
  end

  desc 'Tag a new release'
  task :tag, [:version] do |_t, args|
    version = get_version(args)
    metadata = ReleaseTools::ReleaseMetadata.new
    cng_version = ReleaseTools::CNGVersion.new(version.to_ee)
    omnibus_version =
      ReleaseTools::OmnibusGitlabVersion.new(version.to_omnibus(ee: true))
    charts_version =
      ReleaseTools::Helm::HelmVersionFinder.new.execute(version)

    commits =
      if (env = ENV['STABLE_BRANCH_SOURCE_COMMITS'])
        ReleaseTools::PublicRelease.parse_hash_from_string(env.to_s)
      else
        {}
      end

    ReleaseTools::TraceSection.collapse('Gitaly release', icon: '📦') do
      ReleaseTools::PublicRelease::GitalyMonthlyRelease
        .new(version, release_metadata: metadata, commit: commits[:gitaly])
        .execute
    end

    ReleaseTools::TraceSection.collapse('GitLab release', icon: '📦') do
      ReleaseTools::PublicRelease::GitlabRelease
        .new(version.to_ee, release_metadata: metadata, commit: commits[:gitlab])
        .execute
    end

    ReleaseTools::TraceSection.collapse('Omnibus release', icon: '📦') do
      ReleaseTools::PublicRelease::OmnibusGitlabRelease
        .new(omnibus_version, release_metadata: metadata, commit: commits[:omnibus])
        .execute
    end

    ReleaseTools::TraceSection.collapse('CNG release', icon: '📦') do
      ReleaseTools::PublicRelease::CNGImageRelease
        .new(cng_version, release_metadata: metadata, commit: commits[:cng])
        .execute
    end

    ReleaseTools::TraceSection.collapse('Helm release', icon: '📦') do
      ReleaseTools::PublicRelease::HelmGitlabRelease
        .new(charts_version, version, release_metadata: metadata, commit: commits[:helm])
        .execute
    end

    unless dry_run?
      file_name = version.to_normalized_version

      ReleaseTools::ReleaseMetadataUploader.new.upload(file_name, metadata)
    end
  end

  desc 'Tracks a deployment using the GitLab API'
  task :track_deployment, [:environment, :status, :version] do |_, args|
    env = args[:environment]
    status = args[:status]
    version = args[:version]

    meta = ReleaseTools::Deployments::Metadata.new(version)

    ReleaseTools::SharedStatus.as_security_release(meta.security_release?) do
      tracker = ReleaseTools::Deployments::DeploymentTracker.new(env, status, version)
      deployments = tracker.track

      Raven.capture do
        ReleaseTools::Deployments::MergeRequestLabeler
          .new
          .label_merge_requests(env, deployments)
      end

      ReleaseTools::Deployments::SentryTracker.new.deploy(env, status, version)

      previous, latest = tracker.qa_commit_range
      if previous && latest
        ReleaseTools
          .logger
          .info('Attempting to create QA issue', from: previous, until: latest)

        issue = build_qa_issue(get_version(version: version), previous, latest)

        File.write('QA_ISSUE_URL', "#{issue.url}\n") if ENV['CI'] && issue&.exists?
      end
    end
  end

  desc 'Tags a release candidate if needed'
  task :tag_scheduled_rc do
    unless ReleaseTools::Feature.enabled?(:tag_scheduled_rc)
      ReleaseTools.logger.info('Automatic tagging of RCs is not enabled')
      next
    end

    version = ReleaseTools::AutomaticReleaseCandidate.new.prepare

    ReleaseTools.logger.info('Tagging automatic RC', version: version)

    Rake::Task['release:tag'].invoke(version)
  end

  namespace :gitaly do
    desc 'Tag a new release'
    task :tag, [:version] do |_, args|
      version = get_version(args)

      ReleaseTools::PublicRelease::GitalyMasterRelease.new(version).execute
    end
  end

  namespace :helm do
    desc 'Tag a new release'
    task :tag, [:charts_version, :gitlab_version] do |_t, args|
      charts_version = ReleaseTools::Version.new(args[:charts_version]) if args[:charts_version] && !args[:charts_version].empty?
      gitlab_version = ReleaseTools::Version.new(args[:gitlab_version]) if args[:gitlab_version] && !args[:gitlab_version].empty?

      # At least one of the versions must be provided in order to tag
      if (!charts_version && !gitlab_version) || (charts_version && !charts_version.valid?) || (gitlab_version && !gitlab_version.valid?)
        ReleaseTools.logger.warn('Version number must be in the following format: X.Y.Z')
        exit 1
      end

      ReleaseTools.logger.info(
        'Chart release',
        charts_version: charts_version,
        gitlab_version: gitlab_version
      )

      charts_version ||=
        ReleaseTools::Helm::HelmVersionFinder.new.execute(gitlab_version)

      gitlab_version ||=
        ReleaseTools::Helm::GitlabVersionFinder.new.execute(charts_version)

      ReleaseTools::TraceSection.collapse('Helm release', icon: '📦') do
        ReleaseTools::PublicRelease::HelmGitlabRelease
          .new(charts_version, gitlab_version)
          .execute
      end
    end
  end
end
