# frozen_string_literal: true

module ReleaseTools
  # rubocop: disable Metrics/ClassLength
  class GitlabClient
    include ::SemanticLogger::Loggable

    DEFAULT_GITLAB_API_ENDPOINT = 'https://gitlab.com/api/v4'

    # The regular expression to use for matching auto deploy branch names.
    AUTO_DEPLOY_BRANCH_REGEX = /\A\d+-\d+-auto-deploy-\d{8,}\z/.freeze

    # Some methods get delegated directly to the internal client
    class << self
      extend Forwardable

      def_delegator :client, :job_play

      def_delegator :client, :group_labels
      def_delegator :client, :create_group_label
      def_delegator :client, :create_merge_request_comment
      def_delegator :client, :update_merge_request
      def_delegator :client, :create_variable
      def_delegator :client, :update_variable

      def_delegator :client, :pipeline_schedule
      def_delegator :client, :edit_pipeline_schedule

      def_delegator :client, :version
      def_delegator :client, :issue
    end

    class MissingMilestone
      def id
        nil
      end
    end

    def self.current_user
      @current_user ||= client.user
    end

    def self.default_branch(project)
      client.project(project_path(project)).default_branch
    end

    def self.file_contents(project, *args)
      client.file_contents(project_path(project), *args)
    end

    def self.get_file(project, *args)
      client.get_file(project_path(project), *args)
    end

    def self.create_file(project, *args)
      client.create_file(project_path(project), *args)
    end

    def self.edit_file(project, *args)
      client.edit_file(project_path(project), *args)
    end

    def self.issues(project = Project::GitlabCe, options = {})
      client.issues(project_path(project), options)
    end

    def self.merge_base(project, refs)
      client.merge_base(project_path(project), refs)
    end

    def self.merge_requests(project = Project::GitlabCe, options = {})
      client.merge_requests(project_path(project), options)
    end

    def self.merge_request(project = Project::GitlabCe, iid:)
      client.merge_request(project_path(project), iid)
    end

    def self.pipelines(project = Project::GitlabCe, options = {})
      client.pipelines(project_path(project), options)
    end

    def self.pipeline(project = Project::GitlabCe, pipeline_id)
      client.pipeline(project_path(project), pipeline_id)
    end

    def self.pipeline_jobs(project = Project::GitlabCe, pipeline_id = nil, options = {})
      client.pipeline_jobs(project_path(project), pipeline_id, options)
    end

    # rubocop:disable Metrics/ParameterLists
    def self.pipeline_job_by_name(project = Project::GitlabCe, pipeline_id = nil, job_name = nil, options = {})
      client.pipeline_jobs(project_path(project), pipeline_id, { per_page: 100 }.merge(options)).auto_paginate do |job|
        return job if job.name == job_name
      end
    end
    # rubocop:enable Metrics/ParameterLists

    def self.job_trace(project = Project::GitlabCe, job_id)
      client.job_trace(project_path(project), job_id)
    end

    def self.run_trigger(project = Project::GitlabCe, token, ref, options)
      client.run_trigger(project_path(project), token, ref, options)
    end

    def self.commit_merge_requests(project = Project::GitlabCe, sha:)
      client.commit_merge_requests(project_path(project), sha)
    end

    def self.compare(project = Project::GitlabCe, from:, to:)
      client.compare(project_path(project), from, to)
    end

    def self.commits(project = Project::GitlabCe, options = {})
      client.commits(project_path(project), options)
    end

    def self.commit(project = Project::GitlabCe, ref:)
      client.commit(project_path(project), ref)
    end

    def self.create_commit(project, *args)
      client.create_commit(project_path(project), *args)
    end

    def self.commit_refs(project, sha, options = {})
      # NOTE: The GitLab gem doesn't currently support this API
      # See https://github.com/NARKOZ/gitlab/pull/507
      path = client.url_encode(project_path(project))

      client.get("/projects/#{path}/repository/commits/#{sha}/refs", query: options)
    end

    def self.commit_status(project, sha, options = {})
      client.commit_status(project_path(project), sha, options)
    end

    def self.create_issue_note(project = Project::GitlabCe, issue:, body:)
      client.create_issue_note(project_path(project), issue.iid, body)
    end

    def self.close_issue(project = Project::GitlabCe, issue)
      client.close_issue(project_path(project), issue.iid)
    end

    def self.milestones(project = Project::GitlabCe, options = {})
      # FIXME (rspeicher): See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1032
      project_milestones = client.milestones(project_path(project), options).auto_paginate
      group_milestones = client.group_milestones('gitlab-org', options).auto_paginate

      project_milestones + group_milestones
    end

    def self.current_milestone
      # FIXME (rspeicher): See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1032
      current = milestones(Project::GitlabCe, state: 'active', include_parent_milestones: true)
        .select { |m| current_milestone?(m) }
        .select { |m| m.title.match?(/\A\d+.\d+\z/) }
        .min_by(&:due_date)

      current || MissingMilestone.new
    end

    def self.milestone(project = Project::GitlabCe, title:)
      return MissingMilestone.new if title.nil?

      # FIXME (rspeicher): See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1032
      milestones(project, include_parent_milestones: true)
        .detect { |m| m.title == title } || raise("Milestone #{title} not found for project #{project_path(project)}!")
    end

    # Create an issue in the CE project based on the provided issue
    #
    # issue - An object that responds to the following messages:
    #   :title       - Issue title String
    #   :description - Issue description String
    #   :labels      - Comma-separated String of label names
    #   :version     - Version object
    #   :assignees   - An Array of user IDs to use as the assignees.
    # project - An object that responds to :path
    #
    # The issue is always assigned to the authenticated user.
    #
    # Returns a Gitlab::ObjectifiedHash object
    def self.create_issue(issue, project = Project::GitlabCe)
      milestone = milestone(project, title: issue.version.milestone_name)

      assignees =
        if issue.respond_to?(:assignees)
          issue.assignees
        else
          [current_user.id]
        end

      options = {
        description: issue.description,
        assignee_ids: assignees,
        milestone_id: milestone.id,
        labels: issue.labels,
        confidential: issue.confidential?
      }

      options[:due_date] = issue.due_date if issue.respond_to?(:due_date)

      client.create_issue(
        project_path(project),
        issue.title,
        options
      )
    end

    # Update an issue in the CE project based on the provided issue
    #
    # issue - An object that responds to the following messages:
    #   :title       - Issue title String
    #   :description - Issue description String
    #   :labels      - Comma-separated String of label names
    # project - An object that responds to :path
    #
    # The issue is always assigned to the authenticated user.
    #
    # Returns a Gitlab::ObjectifiedHash object
    def self.update_issue(issue, project = Project::GitlabCe)
      milestone = milestone(project, title: issue.version.milestone_name)

      client.edit_issue(
        project_path(project),
        issue.iid,
        description: issue.description,
        milestone_id: milestone.id,
        labels: issue.labels,
        confidential: issue.confidential?
      )
    end

    # Link an issue as related to another
    #
    # issue - An Issuable object
    # target - An Issuable object
    def self.link_issues(issue, target)
      # NOTE: The GitLab gem doesn't currently support this API
      path = client.url_encode(project_path(issue.project))

      # NOTE: `target_project_id` parameter doesn't support encoded values
      #   See https://gitlab.com/gitlab-org/gitlab/issues/9143
      client.post(
        "/projects/#{path}/issues/#{issue.iid}/links", query: {
          target_project_id: project_path(target.project),
          target_issue_iid: target.iid
        }
      )
    end

    # Create a branch with the given name
    #
    # branch_name - Name of the new branch
    # ref - commit sha or existing branch ref
    # project - An object that responds to :path
    #
    # Returns a Gitlab::ObjectifiedHash object
    def self.create_branch(branch_name, ref, project = Project::GitlabCe)
      client.create_branch(project_path(project), branch_name, ref)
    end

    def self.delete_branch(branch_name, project = Project::GitlabCe)
      client.delete_branch(project_path(project), branch_name)
    end

    def self.branches(project = Project::GitlabCe, options = {})
      client.branches(project_path(project), options)
    end

    # Find a branch in a given project
    #
    # Returns a Gitlab::ObjectifiedHash object, or nil
    def self.find_branch(branch_name, project = Project::GitlabCe)
      client.branch(project_path(project), branch_name)
    rescue Gitlab::Error::NotFound
      nil
    end

    def self.tree(project, options = {})
      client.tree(project_path(project), options)
    end

    def self.find_or_create_branch(branch, ref, project = Project::GitlabCe)
      if (existing = find_branch(branch, project))
        existing
      else
        create_branch(branch, ref, project)
      end
    end

    def self.find_or_create_tag(project, tag, ref, message: nil)
      tag(project, tag: tag)
    rescue Gitlab::Error::NotFound
      create_tag(project, tag, ref, message)
    end

    # Create a merge request in the given project based on the provided merge request
    #
    # merge_request - An object that responds to the following messages:
    #   :title       - Merge request title String
    #   :description - Merge request description String
    #   :labels      - Comma-separated String of label names
    #   :source_branch - The source branch
    #   :target_branch - The target branch
    # project - An object that responds to :path
    #
    # The merge request is always assigned to the authenticated user.
    #
    # Returns a Gitlab::ObjectifiedHash object
    def self.create_merge_request(merge_request, project = Project::GitlabCe)
      milestone =
        if merge_request.milestone.nil?
          current_milestone
        else
          milestone(project, title: merge_request.milestone)
        end

      params = {
        description: merge_request.description,
        assignee_id: current_user.id,
        labels: merge_request.labels,
        source_branch: merge_request.source_branch,
        target_branch: merge_request.target_branch,
        milestone_id: milestone.id,
        remove_source_branch: true
      }

      client.create_merge_request(project_path(project), merge_request.title, params)
    end

    # Accept a merge request in the given project specified by the iid
    #
    # merge_request - An object that responds to the following message:
    #   :iid  - Internal id of merge request
    # project - An object that responds to :path
    #
    # Returns a Gitlab::ObjectifiedHash object
    def self.accept_merge_request(merge_request, project = Project::GitlabCe)
      params = {
        merge_when_pipeline_succeeds: true
      }
      client.accept_merge_request(project_path(project), merge_request.iid, params)
    end

    # Find an issue in the given project based on the provided issue
    #
    # issue - An object that responds to the following messages:
    #   :title  - Issue title String
    #   :labels - Comma-separated String of label names
    # project - An object that responds to :path
    #
    # Returns a Gitlab::ObjectifiedHash object, or nil
    def self.find_issue(issue, project = Project::GitlabCe)
      opts = {
        labels: issue.labels,
        milestone: issue.version.milestone_name,
        search: issue.title
      }

      issues(project, opts).detect { |i| i.title == issue.title }
    end

    # Find an open merge request in the given project based on the provided merge request
    #
    # merge_request - An object that responds to the following messages:
    #   :title  - Merge request title String
    #   :labels - Comma-separated String of label names
    # project - An object that responds to :path
    #
    # Returns a Gitlab::ObjectifiedHash object, or nil
    def self.find_merge_request(merge_request, project = Project::GitlabCe)
      opts = {
        labels: merge_request.labels,
        state: 'opened'
      }

      merge_requests(project, opts)
        .detect { |i| i.title == merge_request.title }
    end

    def self.cherry_pick(project = Project::GitlabCe, ref:, target:, dry_run: false, message: nil)
      raise ArgumentError, "Invalid ref" if ref.blank?

      options = { dry_run: dry_run }

      # If `message` is explicitly passed as `nil`, the Grape API treats this as
      # an empty String, resulting in an empty commit message.
      options[:message] = message if message

      client.cherry_pick_commit(project_path(project), ref, target, options)
    end

    def self.client
      @client ||= Gitlab.client(
        endpoint: DEFAULT_GITLAB_API_ENDPOINT,
        private_token: ENV['RELEASE_BOT_PRODUCTION_TOKEN'],
        httparty: httparty_opts
      )
    end

    def self.httparty_opts
      { logger: logger, log_level: :debug }
    end

    # Overridden by GitLabDevClient
    def self.project_path(project)
      if project.respond_to?(:path)
        project.path
      else
        project
      end
    end

    def self.current_milestone?(milestone)
      return false if milestone.start_date.nil?
      return false if milestone.due_date.nil?

      Date.parse(milestone.start_date) <= Date.today &&
        Date.parse(milestone.due_date) >= Date.today
    end

    def self.last_deployment(project, environment)
      client.environment(project, environment)&.last_deployment
    end

    def self.tag(project, tag:)
      client.tag(project_path(project), tag)
    end

    def self.create_tag(project, *args)
      client.create_tag(project_path(project), *args)
    end

    def self.tags(project, *args)
      client.tags(project_path(project), *args)
    end

    # rubocop: disable Metrics/ParameterLists
    def self.create_deployment(project, environment, ref:, sha:, status:, tag: false)
      client.post(
        "/projects/#{client.url_encode(project_path(project))}/deployments",
        body: {
          ref: ref,
          sha: sha,
          tag: tag,
          status: status,
          environment: environment
        }
      )
    end
    # rubocop: enable Metrics/ParameterLists

    def self.update_deployment(project, id, attrs = {})
      client.put(
        "/projects/#{client.url_encode(project_path(project))}/deployments/#{id}",
        body: attrs
      )
    end

    # rubocop: disable Metrics/ParameterLists
    def self.update_or_create_deployment(project, environment, ref:, sha:, status:, tag: false)
      # First try to find a running deployment with this environment, ref, and sha
      existing = deployments(project, environment, status: 'running')
        .detect { |dep| dep.ref == ref && dep.sha == sha }

      if existing
        update_deployment(project, existing.id, status: status)
      else
        create_deployment(project, environment, ref: ref, sha: sha, status: status, tag: tag)
      end
    end
    # rubocop: enable Metrics/ParameterLists

    def self.deployments(project, environment, status: nil, order_by: 'id', sort: 'desc')
      options = {
        environment: environment,
        order_by: order_by,
        sort: sort
      }
      options[:status] = status if status

      client.deployments(project_path(project), options)
    end

    def self.deployed_merge_requests(project, deployment_id)
      project_path = client.url_encode(project_path(project))

      client.get(
        "/projects/#{project_path}/deployments/#{deployment_id}/merge_requests"
      )
    end

    def self.related_merge_requests(project, issue_iid)
      project_path = client.url_encode(project_path(project))

      client.get(
        "/projects/#{project_path}/issues/#{issue_iid}/related_merge_requests"
      )
    end

    def self.remote_mirrors(project)
      path = project_path(project)

      # NOTE: Experimental API
      client.get("/projects/#{client.url_encode(path)}/remote_mirrors")
    end

    def self.create_merge_request_pipeline(project_id, merge_request_id)
      client.post(
        "/projects/#{client.url_encode(project_id)}/merge_requests/#{merge_request_id}/pipelines"
      )
    end

    def self.compile_changelog(project, version, commit, branch)
      path = project_path(project)

      client.post(
        "/projects/#{client.url_encode(path)}/repository/changelog",
        body: {
          version: version,
          to: commit,
          branch: branch,
          message: "Update changelog for #{version}\n\n[ci skip]"
        }
      )
    end

    def self.merge_request_commits(project, id)
      client.merge_request_commits(project_path(project), id)
    end
  end
  # rubocop: enable Metrics/ClassLength
end
