# frozen_string_literal: true

module ReleaseTools
  # Compiling of Markdown changelogs using the GitLab changelog API.
  class ChangelogCompiler
    include ::SemanticLogger::Loggable

    # The `project` argument is a project _path_, such as
    # `"gitlab-org/gitlab"`. This argument _should not_ be a
    # `ReleaseTools::Project` class, as this Compiler class should not have
    # any knowledge of regular releases, security releases, etc; it's up to a
    # caller to decide what exact project should be used.
    #
    # The `client` argument is a GitLab API client to use, such as
    # `ReleaseTools::GitlabClient`.
    def initialize(project, client: GitlabClient)
      @project = project
      @client = client
    end

    # Compiles the changelog for the given version (a `ReleaseTools::Version`
    # instance).
    #
    # The `branch` argument specifies the branch name to compile the changelog
    # for the release on.
    def compile(version, branch: version.stable_branch)
      commit = @client.commit(@project, ref: branch).id

      compile_on_branch(version, branch, commit)
      compile_on_branch(version, default_branch_name, commit)
    end

    def compile_on_branch(version, branch, commit)
      logger.info(
        "Compiling changelog on branch #{branch.inspect}",
        project: @project,
        version: version,
        commit: commit
      )

      Retriable.with_context(:api) do
        @client.compile_changelog(@project, version.to_patch, commit, branch)
      end
    end

    def default_branch_name
      Retriable.with_context(:api) { @client.default_branch(@project) }
    end
  end
end
