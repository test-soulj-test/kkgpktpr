# frozen_string_literal: true

module ReleaseTools
  class BranchStatus
    include ::SemanticLogger::Loggable

    PROJECTS = [
      Project::GitlabEe,
      Project::GitlabCe,
      Project::OmnibusGitlab
    ].freeze

    def self.for_security_release
      versions = ReleaseTools::Versions
        .next_security_versions
        .map { |v| ReleaseTools::Version.new(v) }

      self.for(versions)
    end

    # Returns a Hash of `project => status` pairs, where `status` is an Array of
    # the results of the latest pipeline for each given version
    def self.for(versions)
      PROJECTS.each_with_object({}) do |project, memo|
        memo[project] = Parallel.map(versions, in_threads: Etc.nprocessors) do |version|
          project_pipeline(project, version)
        end
      end
    end

    private_class_method def self.project_pipeline(project, version)
      # For simplicity's sake, Omnibus will only check the CE branch
      ref = version.stable_branch(ee: project == Project::GitlabEe)

      logger.trace(__method__, project: project, ref: ref)

      ReleaseTools::GitlabDevClient.pipelines(
        project,
        ref: ref,
        per_page: 1
      ).first
    end
  end
end
