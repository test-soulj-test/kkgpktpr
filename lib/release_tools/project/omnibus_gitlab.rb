# frozen_string_literal: true

module ReleaseTools
  module Project
    class OmnibusGitlab < BaseProject
      REMOTES = {
        canonical: 'git@gitlab.com:gitlab-org/omnibus-gitlab.git',
        dev:       'git@dev.gitlab.org:gitlab/omnibus-gitlab.git',
        security:  'git@gitlab.com:gitlab-org/security/omnibus-gitlab.git'
      }.freeze

      def self.metadata_project_name
        'omnibus-gitlab-ee'
      end
    end
  end
end
