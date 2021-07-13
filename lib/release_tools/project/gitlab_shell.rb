# frozen_string_literal: true

module ReleaseTools
  module Project
    class GitlabShell < BaseProject
      REMOTES = {
        canonical: 'git@gitlab.com:gitlab-org/gitlab-shell.git',
        dev:       'git@dev.gitlab.org:gitlab/gitlab-shell.git',
        security:  'git@gitlab.com:gitlab-org/security/gitlab-shell.git'
      }.freeze

      def self.default_branch
        'main'
      end

      def self.version_file
        'GITLAB_SHELL_VERSION'
      end
    end
  end
end
