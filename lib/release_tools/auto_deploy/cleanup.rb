# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    # Cleaning up of old auto-deploy branches.
    class Cleanup
      PROJECTS = [
        Project::GitlabEe,
        Project::OmnibusGitlab,
        Project::CNGImage,
        Project::HelmGitlab
      ].freeze

      # The minimum number of days for which to keep auto-deploy branches. For
      # the value 7, this means we keep auto-deploy branches for the last 7
      # days.
      DAYS_TO_KEEP = 7

      def initialize
        # We store this in an instance variable so all projects use the same
        # minimum date, regardless of the current time. If we were to calculate
        # this on a per project basis, and some projects are cleaned up before
        # midnight while others are cleaned up after it, those projects would
        # have fewer auto-deploy branches left.
        @minimum_date = (Date.today - DAYS_TO_KEEP).to_time
      end

      # Cleans up all outdated auto-deploy branches for all projects that have
      # them.
      def cleanup
        projects = {}

        PROJECTS.each do |project|
          projects[project.path] = GitlabClient
          projects[project.security_path] = GitlabClient
          projects[project.dev_path] = GitlabDevClient
        end

        Parallel.each(projects, in_threads: Etc.nprocessors) do |path, client|
          cleanup_project_branches(path, client)
        end
      end

      # Cleans up all old branches for a project.
      #
      # The `path` argument should be the path to a project.
      #
      # The `client` argument is a GitLab client (e.g. GitlabClient) to use for
      # the project.  If the project path is a path on dev.gitlab.org, make sure
      # that the client is GitlabDevClient instead of the regular GitlabClient.
      def cleanup_project_branches(path, client)
        # We use a Set here, as changes in the list of branches (e.g. a new
        # branch being added while we go through a paginated list) may result in
        # the same branch showing up in different API responses.
        to_delete = Set.new

        client.branches(path, search: '-auto-deploy-').auto_paginate do |branch|
          next unless branch.name.match?(GitlabClient::AUTO_DEPLOY_BRANCH_REGEX)

          begin
            date = auto_deploy_branch_date(branch.name)
          rescue ArgumentError
            ReleaseTools.logger.error(
              "The branch #{branch.name} is not a using a valid auto-deploy branch name",
              project: path
            )

            next
          end

          # Removing during iteration may result in different data being
          # returned per page, which could lead to us not deleting all branches
          # we want to delete.
          #
          # To prevent this from happening, we first record which branches to
          # remove; then remove them separately.
          to_delete.add(branch.name) if date <= @minimum_date
        end

        if to_delete.empty?
          ReleaseTools.logger.info(
            'There are no outdated auto-deploy branches to remove',
            project: path
          )

          return
        end

        ReleaseTools.logger.info(
          "Removing #{to_delete.length} outdated auto-deploy branches",
          project: path
        )

        # Deleting branches in parallel can sometimes result in internal server
        # errors, likely due to Git(aly) not supporting concurrent removals.
        to_delete.each do |branch|
          Retriable.with_context(:api) do
            client.delete_branch(branch, path)
          end
        end
      end

      def auto_deploy_branch_date(name)
        time = name.split('-').last

        begin
          Time.strptime(time, '%Y%m%d%H')
        rescue ArgumentError
          # Until there are no branches without an hour, we need to support
          # both the old and new format.
          Time.strptime(time, '%Y%m%d')
        end
      end
    end
  end
end
