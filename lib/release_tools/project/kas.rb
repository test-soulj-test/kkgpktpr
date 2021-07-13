# frozen_string_literal: true

module ReleaseTools
  module Project
    class Kas < BaseProject
      REMOTES = {
        canonical: 'git@gitlab.com:gitlab-org/cluster-integration/gitlab-agent.git',
        dev:       'git@dev.gitlab.org:gitlab/gitlab-agent.git',
        security:  'git@gitlab.com:gitlab-org/security/cluster-integration/gitlab-agent.git'
      }.freeze

      def self.version_file
        'GITLAB_KAS_VERSION'
      end
    end
  end
end
