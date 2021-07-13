# frozen_string_literal: true

module ReleaseTools
  module CherryPick
    # Performs automated cherry picking to a target branch for the specified
    # version.
    #
    # For the given project, this service will look for merged merge requests on
    # that project labeled `Pick into X.Y` and attempt to cherry-pick their merge
    # commits into the target merge request for the specified version.
    #
    # It will post a comment to each merge request with the status of the pick,
    # and a final summary message with the list of picked and unpicked merge
    # requests for the release managers to perform any further manual actions.
    class StableService
      include ::SemanticLogger::Loggable

      attr_reader :project
      attr_reader :version
      attr_reader :target

      # project - ReleaseTools::Project object
      # version - ReleaseTools::Version object
      # target  - ReleaseTools::PreparationMergeRequest
      def initialize(project, version, target)
        @project = project
        @version = version
        @target = target

        assert_version!
        assert_target!

        @target_branch = @target.branch_name

        @results = []
      end

      def execute
        return [] unless pickable_mrs.any?

        pickable_mrs.auto_paginate do |merge_request|
          cherry_pick(merge_request)
        end

        notifier.summary(
          @results.select(&:success?),
          @results.select(&:failure?)
        )

        notifier.blog_post_summary(@results.select(&:success?))

        @results
      end

      private

      attr_reader :repository

      def assert_version!
        raise "Invalid version provided: `#{version}`" unless version.valid?
      end

      def assert_target!
        raise 'Invalid cherry-pick target provided' unless target.exists?
      end

      def client
        ReleaseTools::GitlabClient
      end

      def notifier
        @notifier ||= StableNotifier.new(version, target: target)
      end

      def cherry_pick(merge_request)
        result = nil

        unless SharedStatus.dry_run?
          cherry_pick_merge_request_commits(merge_request)
        end

        result = Result.new(merge_request, :success)
      rescue Gitlab::Error::Error => ex
        result = Result.new(merge_request, :failure)

        Raven.capture_exception(ex) unless ex.is_a?(Gitlab::Error::BadRequest)
      ensure
        record_result(result)
      end

      def cherry_pick_merge_request_commits(merge_request)
        mr_commits = client
          .merge_request_commits(project, merge_request.iid)
          .auto_paginate
          .reverse

        changelog_commits = changelog_commits(mr_commits)

        if changelog_commits.empty?
          logger.info(
            'No changelog commits found, picking the merge commit',
            merge_request: merge_request.web_url,
            project: project
          )

          # When no changelog entries are introduced, we can just pick the merge
          # request directly.
          client.cherry_pick(
            project,
            ref: merge_request.merge_commit_sha,
            target: @target_branch
          )

          return
        end

        if changelog_commits.length == 1
          # When a single entry is added, we need to reuse the trailers when
          # picking the merge request; otherwise the changelog entry is lost.
          cherry_pick_with_single_changelog_commit(changelog_commits[0], merge_request)

          return
        end

        logger.info(
          'Found multiple changelog commits, picking all commits individually',
          merge_request: merge_request.web_url,
          project: project
        )

        mr_commits.each do |commit|
          client.cherry_pick(
            project,
            ref: commit.id,
            target: @target_branch,
            message: commit.message
          )
        end
      end

      def changelog_commits(commits)
        return commits if commits.empty?

        # The range "A~1..B" is a range where both A and B are incuded. Ranges
        # in the form "A..B" exclude A but include B, which would result in us
        # not considering the first commit in a merge request.
        range = "#{commits.first.id}~1..#{commits.last.id}"

        client
          .commits(project, ref_name: range, trailers: true)
          .auto_paginate
          .reverse
          .select { |c| c.trailers.key?('Changelog') }
      end

      def cherry_pick_with_single_changelog_commit(commit, merge_request)
        logger.info(
          'Found a single changelog commit, picking that commit directly',
          merge_request: merge_request.web_url,
          project: project,
          commit: commit.id
        )

        trailers = commit
          .trailers
          .map { |pair| pair.join(': ') }
          .join("\n")

        message = <<~MSG.strip
          #{merge_request.title}

          See #{merge_request.web_url}

          #{trailers}
        MSG

        client.cherry_pick(
          project,
          ref: merge_request.merge_commit_sha,
          target: @target_branch,
          message: message
        )
      end

      def record_result(result)
        @results << result
        log_result(result)
        notifier.comment(result)
      end

      def log_result(result)
        payload = {
          project: project,
          target: target.branch_name,
          merge_request: result.url
        }

        if result.success?
          logger.info('Cherry-pick merged', payload)
        else
          logger.warn('Cherry-pick failed', payload)
        end
      end

      def pickable_mrs
        @pickable_mrs ||=
          client.merge_requests(
            project,
            state: 'merged',
            labels: PickIntoLabel.for(version),
            order_by: 'created_at',
            sort: 'asc'
          )
      end
    end
  end
end
