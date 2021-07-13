# frozen_string_literal: true

module ReleaseTools
  module Security
    class SyncRemotesService
      include ::SemanticLogger::Loggable
      include ReleaseTools::Services::SyncBranchesHelper

      # Syncs default branch across all remotes
      def initialize
        @projects = [
          ReleaseTools::Project::GitlabEe,
          ReleaseTools::Project::GitlabCe,
          ReleaseTools::Project::OmnibusGitlab,
          ReleaseTools::Project::Gitaly,
          ReleaseTools::Project::HelmGitlab
        ]
      end

      def execute
        @projects.each do |project|
          branches = [project.default_branch]

          logger.info('Syncing branches', project: project, branches: branches)
          sync_branches(project, *branches)
        end
      end
    end
  end
end
