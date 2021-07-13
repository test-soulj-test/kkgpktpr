# frozen_string_literal: true

module ReleaseTools
  module Services
    class AutoDeployBranchService
      include ::SemanticLogger::Loggable
      include BranchCreation

      CI_VAR_AUTO_DEPLOY = 'AUTO_DEPLOY_BRANCH'

      attr_reader :branch_name

      def initialize(branch_name)
        @branch_name = branch_name
      end

      def create_branches!
        # Find passing commits before creating branches
        ref_ee = latest_successful_ref(Project::GitlabEe)
        ref_omnibus = latest_successful_ref(Project::OmnibusGitlab)
        ref_cng = latest_successful_ref(Project::CNGImage)
        ref_helm = latest_successful_ref(Project::HelmGitlab)

        results = [
          create_branch_from_ref(Project::GitlabEe.auto_deploy_path, branch_name, ref_ee),
          create_branch_from_ref(Project::OmnibusGitlab.auto_deploy_path, branch_name, ref_omnibus),
          create_branch_from_ref(Project::CNGImage.auto_deploy_path, branch_name, ref_cng),
          create_branch_from_ref(Project::HelmGitlab.auto_deploy_path, branch_name, ref_helm)
        ]

        update_auto_deploy_ci

        results
      end

      private

      def latest_successful_ref(project)
        PassingBuild.new(project.default_branch, project).execute.id
      end

      def update_auto_deploy_ci
        return if SharedStatus.dry_run?

        gitlab_ops_client = ReleaseTools::GitlabOpsClient

        begin
          gitlab_ops_client.update_variable('gitlab-org/release/tools', CI_VAR_AUTO_DEPLOY, branch_name)
        rescue Gitlab::Error::NotFound
          gitlab_ops_client.create_variable('gitlab-org/release/tools', CI_VAR_AUTO_DEPLOY, branch_name)
        end
      end
    end
  end
end
