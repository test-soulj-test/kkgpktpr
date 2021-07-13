# frozen_string_literal: true

module ReleaseTools
  module Project
    class GitlabWorkhorse < BaseProject
      REMOTES = {
        canonical: 'git@gitlab.com:gitlab-org/gitlab-workhorse.git',
        dev:       'git@dev.gitlab.org:gitlab/gitlab-workhorse.git',
        security:  'git@gitlab.com:gitlab-org/security/gitlab-workhorse.git'
      }.freeze

      def self.version_file
        'GITLAB_WORKHORSE_VERSION'
      end
    end
  end
end
