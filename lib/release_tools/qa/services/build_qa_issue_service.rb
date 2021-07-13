# frozen_string_literal: true

module ReleaseTools
  module Qa
    module Services
      class BuildQaIssueService
        attr_reader :version, :from, :to, :projects

        def initialize(version:, from:, to:, projects:)
          @version = version
          @from = ReleaseTools::Qa::Ref.new(from)
          @to = ReleaseTools::Qa::Ref.new(to)
          @projects = projects
        end

        def execute
          issue
        end

        def issue
          @issue ||= ReleaseTools::Qa::Issue.new(
            version: version,
            project: ReleaseTools::Project::Release::Tasks,
            merge_requests: merge_requests,
            qa_job: gitlab_provisioner_gitlab_qa_job
          )
        end

        def omnibus_gitlab_pipeline
          ReleaseTools::GitlabDevClient.pipelines(Project::OmnibusGitlab, ref: version.to_omnibus(ee: true)).first
        end

        def omnibus_gitlab_ha_validate_tagged_job
          pipeline = omnibus_gitlab_pipeline
          return unless pipeline

          ReleaseTools::GitlabDevClient.pipeline_job_by_name(Project::OmnibusGitlab, pipeline.id, 'HA-Validate-Tagged', scope: 'success')
        end

        def omnibus_gitlab_ha_validate_tagged_job_trace
          job = omnibus_gitlab_ha_validate_tagged_job
          return unless job

          ReleaseTools::GitlabDevClient.job_trace(Project::OmnibusGitlab, job.id)
        end

        def gitlab_provisioner_pipeline
          trace = omnibus_gitlab_ha_validate_tagged_job_trace
          return unless trace

          match = trace.match(%r{^Waiting for downstream pipeline status: https://.+/(?<pipeline_id>\d+)$})
          return unless match

          ReleaseTools::GitlabClient.pipeline(Project::GitlabProvisioner, match[:pipeline_id])
        end

        def gitlab_provisioner_gitlab_qa_job
          pipeline = gitlab_provisioner_pipeline
          return unless pipeline

          ReleaseTools::GitlabClient.pipeline_job_by_name(Project::GitlabProvisioner, pipeline.id, 'gitlab-qa')
        end

        def merge_requests
          MergeRequests.new(projects: projects, from: from, to: to).to_a
        end
      end
    end
  end
end
