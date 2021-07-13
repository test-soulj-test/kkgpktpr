# frozen_string_literal: true

module ReleaseTools
  module Project
    module Release
      class Metadata < Project::BaseProject
        REMOTES = {
          ops: 'git@ops.gitlab.net:gitlab-org/release/metadata.git'
        }.freeze
      end
    end
  end
end
