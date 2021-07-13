# frozen_string_literal: true

module ReleaseTools
  module Services
    module SyncBranchesHelper
      # Number of remotes needed to sync branches
      REMOTES_SIZE = 2

      # Sync project branches across all remotes, it uses all
      # project remotes: Canonical, Dev and Security.
      #
      # Iterates over the branches and for each of them:
      # 1. It clones from Canonical.
      # 2. Fetches the branch from Dev.
      # 3. Merges Dev branch into Canonical branch.
      # 4. If the merge is successful pushes the changes to all remotes.
      #
      # Example:
      #
      # sync_branches(ReleaseTools::Project::GitLabCe, ['main'])
      def sync_branches(project, *branches)
        sync_remotes = project::REMOTES

        return unless valid_remotes?(sync_remotes)

        logger.info('Syncing remotes', project: project, remotes: sync_remotes.keys)

        return if SharedStatus.dry_run?

        branches.each do |branch|
          repository = RemoteRepository.get(sync_remotes, global_depth: 50, branch: branch)

          repository.fetch(branch, remote: :dev)

          result = repository.merge("dev/#{branch}", no_ff: true)

          if result.status.success?
            logger.info('Pushing branch to remotes', project: project, name: branch, remotes: sync_remotes.keys)
            repository.push_to_all_remotes(branch)
          else
            logger.fatal('Failed to sync branch', project: project, name: branch, output: result.output)
          end
        end
      end

      private

      def valid_remotes?(remotes)
        remotes.slice(:canonical, :dev).size == REMOTES_SIZE
      end
    end
  end
end
