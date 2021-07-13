# frozen_string_literal: true

module ReleaseTools
  module Tasks
    module AutoDeploy
      # Post a Slack message after Canary baking time has completed
      class BakingTime
        def execute
          status = ReleaseTools::Promotion::ProductionStatus.new(:canary_up)
          package = ReleaseTools::AutoDeploy::Tag.new.omnibus_package
          foreword = ReleaseTools::Promotion::BakingTimeForeword.new(package)

          Retriable.retriable do
            ReleaseTools::Slack::ChatopsNotification.fire_hook(
              channel: ReleaseTools::Slack::F_UPCOMING_RELEASE,
              blocks: [foreword.to_slack_block] + status.to_slack_blocks
            )
          end
        end
      end
    end
  end
end
