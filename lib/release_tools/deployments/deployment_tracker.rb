# frozen_string_literal: true

module ReleaseTools
  module Deployments
    # Tracking of deployments using the GitLab API
    class DeploymentTracker
      include ::SemanticLogger::Loggable

      # A regex to use for ensuring that we only track Gitaly deployments for
      # SHAs, not tagged versions.
      GITALY_SHA_REGEX = /\A[0-9a-f]{40}\z/.freeze

      # A regex that matches Gitaly tagged releases, such as "12.8.1".
      GITALY_TAGGED_RELEASE_REGEX = /\A\d+\.\d+\.\d+(-rc\d+)?\z/.freeze

      # The deployment statuses that we support.
      DEPLOYMENT_STATUSES = Set.new(%w[running success failed]).freeze

      # A deployment created using the GitLab API
      Deployment = Struct.new(:project_path, :id, :status) do
        def success?
          status == 'success'
        end
      end

      # The name of the staging environment of GitLab.com.
      STAGING = 'gstg'

      # environment - The name of the environment that was deployed to.
      # status - The status of the deployment, such as "success" or "failed".
      # version - The raw deployment version, as passed from the deployer.
      def initialize(environment, status, version)
        @environment = environment
        @status = status
        @version = version
      end

      def qa_commit_range
        unless @environment == STAGING && @status == 'success'
          return []
        end

        current, previous = GitlabClient
          .deployments(
            Project::GitlabEe.auto_deploy_path,
            @environment,
            status: 'success'
          )
          .first(2)
          .map(&:sha)

        [previous, current]
      end

      def track
        logger.info(
          'Recording GitLab deployment',
          environment: @environment,
          status: @status,
          version: @version
        )

        unless DEPLOYMENT_STATUSES.include?(@status)
          raise(
            ArgumentError,
            "The deployment status #{@status} is not supported"
          )
        end

        version = DeploymentVersionParser.new.parse(@version)
        omnibus_version = OmnibusDeploymentVersionParser.new.parse(@version)

        logger.info(
          "Parsed GitLab version from #{@version}",
          sha: version.sha,
          ref: version.ref,
          is_tag: version.tag?
        )

        logger.info(
          "Parsed Omnibus GitLab version from #{@version}",
          sha: omnibus_version.sha,
          ref: omnibus_version.ref,
          is_tag: omnibus_version.tag?
        )

        gitlab_deployments = track_gitlab_deployments(version)
        gitaly_deployments = track_gitaly_deployments(version.sha)
        omnibus_deployments = track_omnibus_deployments(omnibus_version)

        (gitlab_deployments + gitaly_deployments + omnibus_deployments).compact
      end

      private

      # Find the first commit that exists in the Security auto-deploy branch and
      # the Canonical default branch
      #
      # The commit being deployed in the auto-deploy branch is usually something
      # that only exists in that branch, and thus can't be used for a Canonical
      # deployment.
      def auto_deploy_intersection(project, sha)
        canonical = GitlabClient
          .commits(project.path, ref_name: project.default_branch, per_page: 100)
          .paginate_with_limit(300)
          .collect(&:id)

        GitlabClient.commits(project.auto_deploy_path, ref_name: sha).paginate_with_limit(300) do |commit|
          return commit.id if canonical.include?(commit.id)
        end

        logger.warn(
          'Failed to find auto-deploy intersection',
          project: project.path,
          sha: sha
        )

        nil
      rescue Gitlab::Error::Error => ex
        logger.warn(
          'Failed to find auto-deploy intersection',
          project: project.path,
          sha: sha,
          error: ex.message
        )

        nil
      end

      def create_deployments(project, ref:, sha:, is_tag:)
        deployments = []

        log_previous_deployment(project.auto_deploy_path)

        logger.info(
          "Recording #{project.name.demodulize} deployment",
          environment: @environment,
          status: @status,
          sha: sha,
          ref: ref
        )

        data = GitlabClient.update_or_create_deployment(
          project.auto_deploy_path,
          @environment,
          ref: ref,
          sha: sha,
          status: @status,
          tag: is_tag
        )

        log_new_deployment(project.auto_deploy_path, data)

        deployments << Deployment.new(project.auto_deploy_path, data.id, data.status)

        canonical_sha = auto_deploy_intersection(project, sha)
        return deployments unless canonical_sha

        # Because auto-deploy branches only exist on Security, the deploy above
        # was created there.
        #
        # However, merge requests on Canonical still need to be notified about
        # the deployment, but the given ref won't exist there, so we also create
        # one on Canonical using its default branch and the first commit that
        # exists on both Security and Canonical.
        log_previous_deployment(project.path)

        logger.info(
          "Recording #{project.name.demodulize} Canonical deployment",
          environment: @environment,
          status: @status,
          sha: sha,
          ref: project.default_branch
        )

        data = GitlabClient.update_or_create_deployment(
          project.path,
          @environment,
          ref: project.default_branch,
          sha: canonical_sha,
          status: @status,
          tag: is_tag
        )

        log_new_deployment(project.path, data)

        deployments << Deployment.new(project.path, data.id, data.status)
      end

      def track_gitlab_deployments(version)
        create_deployments(
          Project::GitlabEe,
          ref: version.ref,
          sha: version.sha,
          is_tag: version.tag?
        )
      end

      def track_gitaly_deployments(gitlab_sha)
        version = GitlabClient
          .file_contents(
            Project::GitlabEe.auto_deploy_path,
            Project::Gitaly.version_file,
            gitlab_sha
          )
          .strip

        ref, sha, is_tag = gitaly_deployment_details(version)

        create_deployments(
          Project::Gitaly,
          ref: ref,
          sha: sha,
          is_tag: is_tag
        )
      end

      def gitaly_deployment_details(version)
        if version.match?(GITALY_TAGGED_RELEASE_REGEX)
          tag = GitlabClient
            .tag(Project::Gitaly.auto_deploy_path, tag: "v#{version}")

          [tag.name, tag.commit.id, true]
        elsif version.match?(GITALY_SHA_REGEX)
          [Project::Gitaly.default_branch, version, false]
        else
          raise "The Gitaly version #{version} is not recognised"
        end
      end

      def track_omnibus_deployments(version)
        create_deployments(
          Project::OmnibusGitlab,
          ref: version.ref,
          sha: version.sha,
          is_tag: version.tag?
        )
      end

      def log_new_deployment(project_path, deploy)
        logger.info(
          "Created new deployment for #{project_path}",
          path: project_path,
          id: deploy.id,
          iid: deploy.iid,
          ref: deploy.ref,
          sha: deploy.sha
        )
      end

      def log_previous_deployment(project_path)
        deploy = GitlabClient
          .deployments(project_path, @environment, status: 'success')
          .first

        return unless deploy

        logger.info(
          "Previous deployment for #{project_path} is deploy ##{deploy.iid}",
          id: deploy.id,
          iid: deploy.iid,
          ref: deploy.ref,
          sha: deploy.sha
        )
      end
    end
  end
end
