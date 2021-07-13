# frozen_string_literal: true

module ReleaseTools
  module Project
    class MergeTrain < BaseProject
      REMOTES = {
        canonical: 'git@ops.gitlab.net:gitlab-org/merge-train.git'
      }.freeze
    end
  end
end
