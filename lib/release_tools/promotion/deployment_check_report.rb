# frozen_string_literal: true

module ReleaseTools
  module Promotion
    class DeploymentCheckReport
      include ::SemanticLogger::Loggable

      # Initial deployer job that sends the notifications
      INITIAL_DEPLOYER_JOB = 'gprd-migrations 50%'

      # File that stores Slack message ts
      DEPLOYMENT_MESSAGE_TS = 'SLACK_DEPLOYMENT_MESSAGE_TS'

      def initialize(deployment_step, foreword, status)
        @deployment_step = deployment_step
        @foreword = foreword
        @status = status
      end

      def execute
        return if SharedStatus.dry_run?

        if @deployment_step.include?(INITIAL_DEPLOYER_JOB)
          blocks = foreword_block + status_blocks
          message_payload = send_message_to_slack_channel(blocks)

          store_message_payload(message_payload)
        else
          blocks = foreword_block

          add_threaded_message(blocks)
        end
      end

      private

      def foreword_block
        [@foreword.to_slack_block]
      end

      def status_blocks
        @status.to_slack_blocks
      end

      def send_message_to_slack_channel(blocks, thread_ts: nil)
        logger.info('Sending slack message', thread_ts: thread_ts)

        Retriable.retriable do
          ReleaseTools::Slack::Message.post(
            channel: ReleaseTools::Slack::F_UPCOMING_RELEASE,
            message: @foreword.header,
            blocks: blocks,
            thread_ts: thread_ts
          )
        end
      rescue ReleaseTools::Slack::Message::CouldNotPostMessageError => ex
        logger.error('Could not post Slack message', { thread_ts: thread_ts }, ex)

        raise
      end

      def store_message_payload(message_payload)
        File.write(DEPLOYMENT_MESSAGE_TS, message_payload['ts'])
      end

      def add_threaded_message(blocks)
        unless File.exist?(DEPLOYMENT_MESSAGE_TS)
          logger.error("#{DEPLOYMENT_MESSAGE_TS} file doesn't exist")

          return
        end

        thread_ts = File.read(DEPLOYMENT_MESSAGE_TS).strip

        if thread_ts.present?
          logger.info('Slack message ts found, adding threaded message', thread_ts: thread_ts)

          send_message_to_slack_channel(blocks, thread_ts: thread_ts)
        else
          logger.error('Slack message ts not found')

          raise
        end
      end
    end
  end
end
