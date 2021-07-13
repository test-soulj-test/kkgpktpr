# frozen_string_literal: true

module ReleaseTools
  module Project
    class GitlabPages < BaseProject
      REMOTES = {
        canonical: 'git@gitlab.com:gitlab-org/gitlab-pages.git',
        dev:       'git@dev.gitlab.org:gitlab/gitlab-pages.git',
        security:  'git@gitlab.com:gitlab-org/security/gitlab-pages.git'
      }.freeze

      def self.version_file
        'GITLAB_PAGES_VERSION'
      end
    end
  end
end
