# frozen_string_literal: true

module ReleaseTools
  module Project
    module Release
      class Tasks < Project::BaseProject
        REMOTES = {
          canonical: 'git@gitlab.com:gitlab-org/release/tasks.git'
        }.freeze
      end
    end
  end
end
