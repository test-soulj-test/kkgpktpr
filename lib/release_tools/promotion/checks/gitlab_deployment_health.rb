# frozen_string_literal: true

require 'sentry-raven'

module ReleaseTools
  module Promotion
    module Checks
      # GitlabDeploymentHealth checks our production metrics to allow a deployment
      class GitlabDeploymentHealth
        include ::ReleaseTools::Promotion::Check
        include ::SemanticLogger::Loggable

        HEADING = ':crystal_ball: GitLab Deployment Health Status'
        THANOS_URL = 'https://thanos-query.ops.gitlab.net/graph?g0.range_input=6h&g0.stacked=0&g0.max_source_resolution=0s&g0.expr=gitlab_deployment_health%3Aservice%7Benv%3D%22gprd%22%7D&g0.tab=0'

        def name
          'services health'
        end

        def fine?
          !ok_count.zero? && ok_count == services.size
        end

        def to_issue_body
          text = StringIO.new

          text.puts("#{HEADING} - [overview](#{THANOS_URL})\n")
          services_status_markup.each do |status|
            text.puts("* #{status}")
          end

          text.string
        end

        def to_slack_blocks
          [
            {
              type: 'section',
              text: mrkdwn("#{HEADING} - <#{THANOS_URL}|overview>")
            },
            {
              type: 'context',
              elements: services_status_markup.map { |status| mrkdwn(status) }
            }
          ]
        end

        private

        def services
          @services ||=
            begin
              ::ReleaseTools::Promotion::GitlabDeploymentHealth.new.services
            rescue StandardError => ex
              logger.error('Cannot detect gitlab deployment health', error: ex)

              ::Raven.capture_exception(ex)

              [OpenStruct.new(name: "Cannot detect gitlab deployment health, #{ex.message}", fine?: false)]
            end
        end

        def ok_count
          services.count(&:fine?)
        end

        # services_status_markup produces a markup compatible with both
        # GitLab markdown and Slack mrkdwn syntax.
        #
        # @return [Array<String>] one markup line for each service
        def services_status_markup
          return ["#{failure_icon} no data"] if services.empty?

          services.map do |service|
            "#{icon(service)} #{service.name}"
          end
        end
      end
    end
  end
end
