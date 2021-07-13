# frozen_string_literal: true

module ReleaseTools
  class Branch
    attr_reader :name, :project

    def initialize(name:, project:)
      @name = name
      @project = project
    end

    def create(ref:)
      GitlabClient.create_branch(name, ref, project)
    end
  end
end
