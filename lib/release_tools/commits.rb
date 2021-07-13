# frozen_string_literal: true

module ReleaseTools
  class Commits
    include ::SemanticLogger::Loggable

    MAX_COMMITS_TO_CHECK = 100

    def initialize(project, ref: project.default_branch, client: ReleaseTools::GitlabClient)
      @project = project
      @ref = ref
      @client = client
    end

    def merge_base(other_ref)
      @client.merge_base(@project.auto_deploy_path, [@ref, other_ref])&.id
    end

    # Get the latest commit for `ref`
    def latest
      commit_list.first
    end

    def latest_successful
      commit_list.detect { |commit| success?(commit) }
    end

    # Find a commit with a passing build on production that also exists on dev
    #
    # limit - If given a SHA String, will stop searching once it's reached
    def latest_successful_on_build(limit: nil)
      commit_list.detect do |commit|
        if commit.id == limit
          logger.info('Reached the limit commit', project: @project.auto_deploy_path, limit: limit)

          next true
        end

        next unless success?(commit)

        begin
          # Hit the dev API with the specified commit to see if it even exists
          ReleaseTools::GitlabDevClient
            .commit(@project.dev_path, ref: commit.id)

          logger.info(
            'Passing commit found on Build',
            project: @project.auto_deploy_path,
            commit: commit.id
          )
        rescue Gitlab::Error::Error
          logger.debug(
            'Commit passed on Canonical, missing on Build',
            project: @project.auto_deploy_path,
            commit: commit.id
          )

          false
        end
      end
    end

    private

    def commit_list
      @commit_list ||= @client.commits(
        @project.auto_deploy_path,
        per_page: MAX_COMMITS_TO_CHECK,
        ref_name: @ref
      )
    end

    def success?(commit)
      result = @client.commit(@project.auto_deploy_path, ref: commit.id)

      case result.status
      when 'preparing', 'pending', 'running', 'canceled'
        return false unless @project == ReleaseTools::Project::GitlabEe

        # When a new auto-deploy branch is created, some commits may only have a
        # pipeline on the default branch. It's also possible that there _is_ a
        # pipeline, but that it only recently started.
        #
        # In both cases it's fine to tag the commit if it passed on the default
        # branch.
        return success_on_default_branch?(commit)
      when 'success'
        # Further check the pipeline status.
        return true if @project != ReleaseTools::Project::GitlabEe
      else
        logger.info(
          'Skipping commit because the pipeline did not succeed',
          commit: commit.id,
          status: result.status
        )

        return false
      end

      # Documentation-only changes result in a pipeline with only a few jobs.
      # If we were to include a passing documentation pipeline/commit, we may
      # end up also including code that broke a previous full pipeline.
      #
      # We also take into account QA only pipelines. These pipelines _should_ be
      # considered, but don't have a regular full pipeline. The "build-assets-image"
      # job is present for both regular and QA pipelines, but not for
      # documentation pipelines; hence we check for the presence of this job.
      # This is more reliable than just checking the amount of jobs.
      return true if full_pipeline?(result.last_pipeline)

      logger.info(
        'Skipping commit because we could not find a full successful pipeline',
        commit: commit.id
      )

      false
    end

    def full_pipeline?(pipeline)
      @client
        .pipeline_jobs(@project.auto_deploy_path, pipeline.id)
        .auto_paginate do |job|
          return true if job.name.start_with?('build-assets-image')
        end

      false
    end

    def success_on_default_branch?(commit)
      @client
        .pipelines(
          @project.auto_deploy_path,
          sha: commit.id,
          ref: @project.default_branch,
          status: 'success'
        )
        .auto_paginate do |pipeline|
          return true if full_pipeline?(pipeline)
        end

      false
    end
  end
end
