# frozen_string_literal: true

module ReleaseTools
  class PassingBuild
    include ::SemanticLogger::Loggable

    attr_reader :ref

    def initialize(ref, project = ReleaseTools::Project::GitlabEe)
      @project = project
      @ref = ref
    end

    def execute
      commits = ReleaseTools::Commits.new(@project, ref: ref)

      commit =
        if Feature.enabled?(:auto_deploy_tag_latest)
          commits.latest
        else
          min = AutoDeploy::MinimumCommit.new(@project, ref).sha

          commits.latest_successful_on_build(limit: min)
        end

      if commit.nil?
        raise "Unable to find a passing #{@project} build for `#{ref}` on dev"
      end

      commit
    end
  end
end
