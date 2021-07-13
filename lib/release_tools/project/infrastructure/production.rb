# frozen_string_literal: true

module ReleaseTools
  module Project
    module Infrastructure
      class Production < Project::BaseProject
        REMOTES = {
          canonical: 'git@gitlab.com:gitlab-com/gl-infra/production.git'
        }.freeze
      end
    end
  end
end
