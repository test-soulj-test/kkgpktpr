# frozen_string_literal: true

module ReleaseTools
  module Services
    # Updates a single component version in GitLab to its latest passing refs
    class UpdateComponentService
      include ::SemanticLogger::Loggable

      # The project that receives updated component info
      TARGET_PROJECT = ReleaseTools::Project::GitlabEe

      attr_reader :target_branch, :component

      # @param component [Project class] the component project class
      # @param target_branch [string] the branch to update
      def initialize(component, target_branch)
        @component = component
        @target_branch = target_branch
      end

      def execute
        unless changed?
          logger.info('Component version already up to date', component: name, version: latest_successful_ref)
          return
        end

        update!
      end

      def changed?
        current_version != latest_successful_ref
      end

      private

      def name
        component.project_name
      end

      def gitlab_client
        ReleaseTools::GitlabClient
      end

      def current_version
        logger.info('Finding the current component version', component: name, branch: target_branch)

        @current_version ||= gitlab_client
          .file_contents(TARGET_PROJECT, component.version_file, target_branch)
          .chomp
      end

      def latest_successful_ref
        @latest_successful_ref ||=
          ReleaseTools::Commits.new(component, client: gitlab_client)
            .latest_successful.id
      end

      def update!
        logger.info('Updating component version', component: name, branch: target_branch, version: latest_successful_ref)
        return if SharedStatus.dry_run?

        action = {
          action: 'update',
          file_path: "/#{component.version_file}",
          content: "#{latest_successful_ref}\n"
        }

        gitlab_client.create_commit(
          gitlab_client.project_path(TARGET_PROJECT),
          target_branch,
          "Update #{name} to #{latest_successful_ref[0...11]}",
          [action]
        )
      end
    end
  end
end
