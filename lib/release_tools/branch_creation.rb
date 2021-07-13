# frozen_string_literal: true

module ReleaseTools
  module BranchCreation
    Result = Struct.new(:project, :branch, :response)

    def gitlab_client
      ReleaseTools::GitlabClient
    end

    def create_branch_from_ref(project, branch, ref)
      logger&.info('Creating branch', name: branch, from: ref, project: project)

      return if ReleaseTools::SharedStatus.dry_run?

      Result.new(
        project,
        branch,
        gitlab_client.find_or_create_branch(branch, ref, project)
      )
    end
  end
end
