# frozen_string_literal: true

module ReleaseTools
  module Project
    class Gitaly < BaseProject
      REMOTES = {
        canonical: 'git@gitlab.com:gitlab-org/gitaly.git',
        dev:       'git@dev.gitlab.org:gitlab/gitaly.git',
        security:  'git@gitlab.com:gitlab-org/security/gitaly.git'
      }.freeze

      def self.version_file
        'GITALY_SERVER_VERSION'
      end
    end
  end
end
