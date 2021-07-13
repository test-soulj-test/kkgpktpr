# frozen_string_literal: true

module ReleaseTools
  module Promotion
    # Provides an introductory Slack block for deployment check report
    class DeploymentCheckForeword
      def initialize(package_version, deployment_step, job_url)
        @package_version = package_version
        @deployment_step = deployment_step
        @job_url = job_url
      end

      def to_slack_block
        text = StringIO.new
        text.puts(header)
        text.puts
        text.puts("Package version: `#{package_version}`")

        {
          type: 'section',
          text: ::ReleaseTools::Slack::Webhook.mrkdwn(text.string)
        }
      end

      def header
        ":ci_running: Production deployment reached #{deployment_job_url}"
      end

      private

      attr_reader :package_version, :deployment_step, :job_url

      def deployment_job_url
        "<#{job_url}|#{deployment_step}>"
      end

      def release_managers_mention
        "<!subteam^#{ReleaseManagers::SlackWrapperClient::RELEASE_MANAGERS_USER_GROUP_ID}>"
      end
    end
  end
end
