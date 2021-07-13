# frozen_string_literal: true

module ReleaseTools
  module Project
    class GitlabCe < BaseProject
      REMOTES = {
        canonical: 'git@gitlab.com:gitlab-org/gitlab-foss.git',
        dev:       'git@dev.gitlab.org:gitlab/gitlabhq.git',
        security:  'git@gitlab.com:gitlab-org/security/gitlab-foss.git'
      }.freeze

      def self.default_branch
        if Feature.enabled?(:switch_to_main_branch)
          'main'
        else
          super
        end
      end

      def self.metadata_project_name
        'gitlab-ce'
      end
    end
  end
end
