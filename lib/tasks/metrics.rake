# frozen_string_literal: true

desc 'Execute all metrics tasks'
task :metrics do
  tasks = %w[
    auto_deploy_pressure
    release_pressure
  ]

  errors = []

  Parallel.each(tasks, in_threads: Etc.nprocessors) do |task|
    Rake::Task["metrics:#{task}"].invoke
  rescue StandardError => ex
    ReleaseTools.logger.warn("Error updating metric", { task: task }, ex)

    errors << ex
  end

  abort if errors.any?
end

namespace :metrics do
  desc "Update auto-deploy pressure metric"
  task :auto_deploy_pressure do
    ReleaseTools::Metrics::AutoDeployPressure.new.execute
  end

  desc "Update release pressure metric"
  task :release_pressure do
    ReleaseTools::Metrics::ReleasePressure.new.execute
  end
end
