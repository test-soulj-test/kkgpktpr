# frozen_string_literal: true

module ReleaseTools
  module Promotion
    class Manager
      include ::SemanticLogger::Loggable

      class UnsafeProductionError < StandardError; end

      attr_reader :pipeline_url, :skip_active_deployment_check

      def initialize(pipeline_url: nil, skip_active_deployment_check: false)
        @pipeline_url = pipeline_url
        @skip_active_deployment_check = skip_active_deployment_check
      end

      def status
        @status ||= ProductionStatus.new(skip_active_deployment_check: skip_active_deployment_check)
      end

      # Authorize production promotion based on the current system status
      #
      # @param package_version [String] the package we want to promote
      # @param issue [ReleaseTools::Issue] the issue to track the outcome
      # @raise [UnsafeProductionError] if the deployment isn't authorized
      def authorize!(package_version, issue)
        Retriable.with_context(:api) do
          create_issue_comment(issue, package_version)
        end

        raise UnsafeProductionError unless safe?
      end

      # check_status will send a slack message with the current status
      #
      # @param slack_channel [String] the slack channel id
      def check_status(slack_channel, raise_on_failure: false)
        # NOTE: Using a new ProductionStatus instance to include CanaryUp check
        status = ProductionStatus.new(:canary_up, skip_active_deployment_check: skip_active_deployment_check)

        notify_on_slack(slack_channel, status.to_slack_blocks)

        raise UnsafeProductionError if raise_on_failure && !status.fine?
      end

      def production_issue_report(project:, issue_iid:)
        body = status.to_issue_body

        Retriable.with_context(:api) do
          GitlabClient.create_issue_note(
            project,
            issue: GitlabClient.issue(project, issue_iid),
            body: body
          )
        end
      rescue Gitlab::Error::NotFound
        err = "Unable to find issue for #{project} with iid: #{issue_iid}"
        logger.fatal(err)
        raise err
      end

      def deployment_check_report(package_version, deployment_step, deployment_job_url)
        foreword = DeploymentCheckForeword.new(package_version, deployment_step, deployment_job_url)

        DeploymentCheckReport.new(deployment_step, foreword, status).execute
      end

      private

      def safe?
        ignore_production_checks? || status.fine?
      end

      # ignore_production_checks return the reason for bypassing production checks
      #
      # Production check bypassing starts with a chatops command.
      # If the release manager provides a reason for bypassing the checks,
      # it will be propagated to the deployer, and then to release-tools using
      # the IGNORE_PRODUCTION_CHECKS trigger variable.
      # On every stage this defaults to 'false', meaning that checks should not
      # be ignored.
      #
      # @return [String] the reason for bypassing the production checks, defaults to 'false'
      def ignore_production_checks
        CGI.unescape(ENV.fetch('IGNORE_PRODUCTION_CHECKS', 'false'))
      end

      # ignore_production_checks? verifies if a reason for bypassing production checks was provided
      #
      # @see Manager#ignore_production_checks
      def ignore_production_checks?
        ignore_production_checks != 'false'
      end

      def note(package_version)
        StatusNote.new(
          status: status,
          package_version: package_version,
          ci_pipeline_url: pipeline_url,
          release_manager: release_manager,
          override_status: ignore_production_checks?,
          override_reason: ignore_production_checks
        )
      end

      def release_manager
        ops_user = ENV['RELEASE_MANAGER']
        return ':warning: Unknown release manager! Missing `RELEASE_MANAGER` variable' if ops_user.nil?

        user = ReleaseManagers::Definitions.new.find_user(ops_user, instance: :ops)

        return ":warning: Unknown release manager! OPS username #{ops_user}" if user.nil?

        "@#{user.production}"
      end

      def create_issue_comment(issue, package_version)
        if SharedStatus.dry_run?
          logger.warn(
            'Dry run mode, no comment will be posted',
            issue: issue.url,
            package_version: package_version,
            production_healthy: status.fine?,
            ignore_production_checks: ignore_production_checks
          )

          return
        end

        GitlabClient.create_issue_note(
          issue.project,
          issue: issue,
          body: note(package_version).body
        )
      end

      def notify_on_slack(channel, blocks)
        if SharedStatus.dry_run?
          logger.warn('Dry run mode, no Slack notification will be sent')

          return
        end

        Retriable.retriable do
          Slack::ChatopsNotification.fire_hook(channel: channel, blocks: blocks)
        end
      rescue ReleaseTools::Slack::Webhook::CouldNotPostError
        logger.error('Malformed slack request', channel: channel, blocks: blocks.to_json)

        raise
      end
    end
  end
end
