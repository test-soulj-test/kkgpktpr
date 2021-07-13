# frozen_string_literal: true

module ReleaseTools
  module Project
    class HelmGitlab < BaseProject
      REMOTES = {
        canonical: 'git@gitlab.com:gitlab-org/charts/gitlab.git',
        security:  'git@gitlab.com:gitlab-org/security/charts/gitlab.git',
        dev:       'git@dev.gitlab.org:gitlab/charts/gitlab.git'
      }.freeze
    end
  end
end
