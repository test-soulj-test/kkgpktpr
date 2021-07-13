# frozen_string_literal: true

module ReleaseTools
  module Slack
    class ChatopsNotification < Webhook
      def self.channel
        ENV.fetch('CHAT_CHANNEL', nil)
      end

      def self.job_url
        ENV.fetch('CI_JOB_URL', 'https://example.com/')
      end

      def self.task
        ENV.fetch('TASK', '')
      end

      def self.webhook_url
        ENV.fetch('SLACK_CHATOPS_URL')
      end

      def self.release_issue(issue)
        return unless task.present?

        text = "The `#{task}` command at #{job_url} completed!"
        attachment = {
          fallback: '',
          color: issue.status == :created ? 'good' : 'warning',
          title: issue.title,
          title_link: issue.url
        }

        fire_hook(text: text, attachments: [attachment], channel: channel)
      end

      # @param [ReleaseTools::Security::BatchMergerResult] merge_result
      def self.security_merge_requests_processed(result)
        text = "The `merge` command at #{job_url} completed!"
        attachments = result.build_attachments

        return if attachments.empty?

        fire_hook(text: text, blocks: attachments, channel: channel)
      end

      # @param [ReleaseTools::Security::IssuesResult] issues_result
      def self.security_implementation_issues_processed(result)
        fire_hook(
          channel: channel,
          blocks: result.build_attachments
        )
      end

      def self.branch_status(status)
        return unless status.any?

        fields = []

        status.each_pair do |project, values|
          text = ["*#{project}*"]

          text << values.map do |result|
            ":status_#{result.status}: <#{result.web_url}|#{result.ref}>"
          end

          fields << mrkdwn(text.join("\n"))
        end

        blocks = [{ type: 'section', fields: fields }]

        fire_hook(channel: channel, blocks: blocks)
      end
    end
  end
end
