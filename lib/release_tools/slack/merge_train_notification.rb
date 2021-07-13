# frozen_string_literal: true

module ReleaseTools
  module Slack
    class MergeTrainNotification < Webhook
      def self.webhook_url
        # Auto-deploy notifications go to `#releases`, which makes sense for
        # this notification too
        ENV.fetch('AUTO_DEPLOY_NOTIFICATION_URL')
      end

      def self.toggled(schedule)
        fallback = "Merge train toggled"

        text = ":train: The *#{schedule.description}* merge train task has been"
        text +=
          if schedule.active
            " activated due to a branch divergence."
          else
            " deactivated because it's no longer necessary."
          end

        blocks = [
          {
            type: 'section',
            text: mrkdwn(text)
          }
        ]

        fire_hook(text: fallback, blocks: blocks)
      end
    end
  end
end
