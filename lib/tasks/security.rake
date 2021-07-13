namespace :security do
  # Undocumented; should be a pre-requisite for every task in this namespace!
  task :force_security do
    unless ReleaseTools::SharedStatus.critical_security_release?
      ENV['SECURITY'] = 'true'
    end
  end

  desc 'Create a security release task issue'
  task issue: :force_security do |_t, args|
    issue = ReleaseTools::SecurityPatchIssue.new(versions: args[:versions])

    create_or_show_issue(issue)
  end

  desc 'Merges valid security merge requests'
  task :merge, [:merge_default] => :force_security do |_t, args|
    merge_default =
      if args[:merge_default] && !args[:merge_default].empty?
        true
      else
        false
      end

    ReleaseTools::Security::MergeRequestsMerger
      .new(merge_default: merge_default)
      .execute
  end

  desc 'Toggle the security merge train based on need'
  task :merge_train do |_t, _args|
    ReleaseTools::Security::MergeTrainService
      .new
      .execute
  end

  desc 'Prepare for a new security release'
  task prepare: :force_security do |_t, _args|
    issue_task = Rake::Task['security:issue']
    versions = []

    ReleaseTools::Versions.next_security_versions.each do |version|
      versions << get_version(version: version)
    end

    issue_task.execute(versions: versions)
  end

  desc 'Create a security QA issue'
  task :qa, [:from, :to] => :force_security do |_t, args|
    Rake::Task['release:qa'].invoke(*args)
  end

  desc "Check a security release's build status"
  task status: :force_security do |t, _args|
    status = ReleaseTools::BranchStatus.for_security_release

    status.each_pair do |project, results|
      results.each do |result|
        ReleaseTools.logger.tagged(t.name) do
          ReleaseTools.logger.info(project, result.to_h)
        end
      end
    end

    ReleaseTools::Slack::ChatopsNotification.branch_status(status)
  end

  desc 'Tag a new security release'
  task :tag, [:version] => :force_security do |_t, args|
    $stdout
      .puts "Security Release - using security repository only!\n"
      .colorize(:red)

    Rake::Task['release:tag'].invoke(*args)
  end

  desc 'Validates merge requests in security projects'
  task validate: :force_security do
    ReleaseTools::Security::ProjectsValidator
      .new(ReleaseTools::Security::Client.new)
      .execute
  end

  desc 'Sync default and auto-deploy branches'
  task sync_remotes: :force_security do
    ReleaseTools::Security::SyncRemotesService
      .new
      .execute
  end

  desc 'Close implementation issues'
  task close_issues: :force_security do
    ReleaseTools::Security::CloseImplementationIssues
      .new
      .execute
  end

  desc 'Create a Security Release Tracking Issue'
  task tracking_issue: :force_security do
    security_tracking_issue = ReleaseTools::Security::TrackingIssue.new

    security_tracking_issue.close_outdated_issues

    create_or_show_issue(security_tracking_issue)
  end

  namespace :gitaly do
    desc 'Tag a new Gitaly security release'
    task :tag, [:version] => :force_security do |_, args|
      Rake::Task['release:gitaly:tag'].invoke(*args)
    end
  end
end
