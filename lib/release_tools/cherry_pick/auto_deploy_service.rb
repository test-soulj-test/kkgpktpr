# frozen_string_literal: true

module ReleaseTools
  module CherryPick
    # Performs automated cherry-picking into an auto-deploy branch
    #
    # Given a `project`, gathers merged MRs labeled `Pick into auto-deploy` and
    # attempts to cherry-pick their merge commit into the auto-deploy branch
    # specified by `target`.
    #
    # Each MR will receive a comment indicating the result of the attempt.
    class AutoDeployService
      # Raised when a target merge commit isn't available on Security
      MirrorError = Class.new(StandardError)

      include ::SemanticLogger::Loggable

      attr_reader :project
      attr_reader :target

      # project - ReleaseTools::Project object
      # target  - Auto-deploy branch name
      def initialize(project, target)
        @project = project
        @target = target

        @results = []
      end

      def execute
        return [] unless pickable_mrs.any?

        pickable_mrs.auto_paginate do |merge_request|
          result =
            if allowed?(merge_request)
              cherry_pick(merge_request)
            else
              Result.new(merge_request, :denied, 'Missing ~severity::1 or ~severity::2 label')
            end

          record_result(result)
        end

        @results
      end

      private

      def client
        ReleaseTools::GitlabClient
      end

      def notifier
        @notifier ||= AutoDeployNotifier.new(target, project)
      end

      # Attempt to cherry-pick a merge request into the auto-deploy branch
      #
      # Returns a Result object
      def cherry_pick(merge_request)
        assert_mirrored!(merge_request.merge_commit_sha)

        unless SharedStatus.dry_run?
          client.cherry_pick(
            project.auto_deploy_path,
            ref: merge_request.merge_commit_sha,
            target: @target
          )
        end

        Result.new(merge_request, :success)
      rescue Gitlab::Error::Error => ex
        Result.new(merge_request, :failure, ex.message)
      end

      def allowed?(merge_request)
        merge_request.labels.include?('severity::1') ||
          merge_request.labels.include?('severity::2')
      end

      # Verify the merge commit has been mirrored to the Security repository
      def assert_mirrored!(merge_commit_sha)
        Retriable.with_context(:api, tries: 10) do
          client.commit(project.security_path, ref: merge_commit_sha)
        end
      rescue ::Gitlab::Error::NotFound
        # If the commit still isn't available after retries, something may be
        # wrong with our mirroring or merge-train, and we should fail loudly
        raise MirrorError, "Unable to find #{merge_commit_sha} on #{project.security_path}"
      end

      def record_result(result)
        @results << result
        log_result(result)
        notifier.comment(result)
      end

      def log_result(result)
        payload = {
          project: project,
          target: @target,
          merge_request: result.url
        }

        payload[:reason] = result.reason if result.reason

        if result.success?
          logger.info('Cherry-pick merged', payload)
        elsif result.denied?
          logger.info('Cherry-pick denied', payload)
        else
          logger.warn('Cherry-pick failed', payload)
        end
      end

      def pickable_mrs
        @pickable_mrs ||=
          client.merge_requests(
            project,
            state: 'merged',
            labels: PickIntoLabel.for(:auto_deploy),
            order_by: 'created_at',
            sort: 'asc'
          )
      end
    end
  end
end
