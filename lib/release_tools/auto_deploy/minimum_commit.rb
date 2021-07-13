# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    # Finding of the minimum/oldest commit to tag during an auto-deploy tagging
    # run.
    class MinimumCommit
      include ::SemanticLogger::Loggable

      TAGS_PROJECT = Project::ReleaseTools.ops_path

      def initialize(project, branch)
        @project = project
        @branch = branch
      end

      def sha
        date = AutoDeployBranch.new(@branch).date

        # There may be more than one tag for an auto-deploy branch, so we need
        # to make sure we only use the latest tag.
        tag = GitlabOpsClient
          .tags(TAGS_PROJECT, search: date, sort: 'desc', order_by: 'name')
          .first

        unless tag
          logger.warn('No matching tag found', query: date)

          return
        end

        sha = GitlabOpsClient
          .release_metadata(Version.new(tag.name))
          .dig('releases', @project.metadata_project_name, 'sha')

        logger.info('Minimum commit pulled from metadata', tag: tag.name, sha: sha)

        sha
      end
    end
  end
end
