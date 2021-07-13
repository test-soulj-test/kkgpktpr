# frozen_string_literal: true

module ReleaseTools
  module Slack
    class AutoDeployNotification < Webhook
      def self.webhook_url
        ENV.fetch('AUTO_DEPLOY_NOTIFICATION_URL')
      end

      def self.on_create(results)
        return unless results.any?

        branch = results.first.branch
        fallback = "New auto-deploy branch: `#{branch}`"

        blocks = [
          {
            type: 'section',
            text: mrkdwn(fallback)
          },
          {
            type: 'section',
            fields: results.map do |result|
              mrkdwn("<#{commits_url(result.project, branch)}|#{result.project}>")
            end
          }
        ]

        if ENV['CI_JOB_URL']
          blocks << {
            type: 'context',
            elements: [
              mrkdwn("Created via <#{ENV['CI_JOB_URL']}|scheduled pipeline>.")
            ]
          }
        end

        fire_hook(text: fallback, blocks: blocks)
      end

      def self.on_wait_failure(exception)
        text = "#{exception.message}."

        blocks = ::Slack::BlockKit.blocks
        blocks.section do |block|
          block.mrkdwn(text: "<!subteam^#{RELEASE_MANAGERS}> #{text}")
        end

        blocks.context do |block|
          block.mrkdwn(text: "Job: <#{ENV['CI_JOB_URL']}>")

          if exception.pipeline
            block.mrkdwn(text: "Pipeline: <#{exception.pipeline.web_url}>")
          end
        end

        fire_hook(text: text, blocks: blocks.as_json, channel: F_UPCOMING_RELEASE)
      end

      def self.on_stale_gitaly_merge_request(merge_request)
        text = "A merge request to update the Gitaly version has been open for too long"
        attachment = {
          fallback: text,
          color: 'warning',
          title: merge_request.title,
          title_link: merge_request.url
        }

        fire_hook(text: text, attachments: [attachment], channel: GITALY_ALERTS)
      end

      def self.commits_url(project, branch)
        "https://gitlab.com/#{project}/commits/#{branch}"
      end
    end
  end
end
