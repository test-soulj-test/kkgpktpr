# frozen_string_literal: true

module ReleaseTools
  module Promotion
    # BakingTimeForeword provides an introductory Slack block for the baking time report
    class BakingTimeForeword
      attr_reader :package_version, :pipeline_url

      def initialize(package_version)
        @package_version = package_version
        @pipeline_url = ENV.fetch('CI_PIPELINE_URL', nil)
      end

      def to_slack_block
        text = StringIO.new
        text.puts(":timer_clock: #{release_managers_mention} baking time completed")
        text.puts
        text.puts("Package version: `#{package_version}`")
        text.puts("Deployment: <#{pipeline_url}|pipeline>") if pipeline_url

        {
          type: 'section',
          text: ::ReleaseTools::Slack::Webhook.mrkdwn(text.string)
        }
      end

      private

      def release_managers_mention
        "<!subteam^#{ReleaseTools::Slack::RELEASE_MANAGERS}>"
      end
    end
  end
end
