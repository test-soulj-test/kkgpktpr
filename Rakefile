# frozen_string_literal: true

require_relative 'lib/release_tools'
require_relative 'lib/release_tools/tasks'

# TODO: helpers for backward compatibility
include ReleaseTools::Tasks::Helper

# monkeypatching to ensure uncaught exception are logged on elastic search
module Rake
  class Task
    include ::SemanticLogger::Loggable

    alias_method :invoke_without_log, :invoke

    def invoke(*args)
      begin
        invoke_without_log(*args)
      ensure
        last_exception = $!
        return if last_exception.nil?

        logger.fatal('Task failed', last_exception)
      end
    end
  end
end

Dir.glob('lib/tasks/*.rake').each { |task| import(task) }

# Undocumented; executed via CI schedule
task :close_expired_qa_issues do
  ReleaseTools::Qa::IssueCloser.new.execute
end

desc "Publish packages, tags, stable branches, CNG images, and Helm chart for a specified version"
task :publish, [:version] do |_t, args|
  version = get_version(args)
  pipelines = []

  pipelines.concat(
    ReleaseTools::TraceSection.collapse('Publishing Omnibus', icon: '📤') do
      ReleaseTools::Services::OmnibusPublishService
        .new(version)
        .execute
    end
  )

  # Ensure any exceptions raised by this new service don't fail the build, since
  # all destructive behaviors are behind feature flags.
  ReleaseTools::TraceSection.collapse('Syncing remotes', icon: '🔄') do
    Raven.capture do
      ReleaseTools::Services::SyncRemotesService
        .new(version)
        .execute
    end
  end

  # Both the CNG and Helm charts publish jobs rely on the tag having been pushed
  # to gitlab.com, so we run these after the remote sync
  pipelines.concat(
    ReleaseTools::TraceSection.collapse('Publishing CNG', icon: '📤') do
      ReleaseTools::Services::CNGPublishService
        .new(version)
        .execute
    end
  )

  chart_version = ReleaseTools::Helm::HelmVersionFinder.new.execute(version)

  pipelines.concat(
    ReleaseTools::TraceSection.collapse('Publishing Helm', icon: '📤') do
      ReleaseTools::Services::HelmChartPublishService
        .new(chart_version)
        .execute
    end
  )

  if pipelines.any?
    puts <<~MESSAGE
      The publishing jobs have started. Please keep an eye on the following
      pipelines and make sure that they all pass:

      - #{pipelines.map(&:web_url).join("\n- ")}
    MESSAGE
  else
    puts <<~ERROR.bold.yellow
      No pipelines were found. This means none of the publishing pipelines have
      any manual jobs that hadn't been triggered yet.
    ERROR
  end
end
