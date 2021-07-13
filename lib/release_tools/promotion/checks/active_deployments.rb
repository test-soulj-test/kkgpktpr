# frozen_string_literal: true

module ReleaseTools
  module Promotion
    module Checks
      class ActiveDeployments
        include ::ReleaseTools::Promotion::Check

        def name
          'production deployments'
        end

        def fine?
          chef_client.environment_enabled?
        end

        def to_slack_blocks
          text = StringIO.new
          text.puts("#{icon(self)} *#{name}*")

          unless fine?
            text.puts("Production environment locked: There's an active production deployment, see the <#{pipeline_url}|deployer pipeline>")
          end

          [
            {
              type: 'section',
              text: mrkdwn(text.string)
            }
          ]
        end

        def to_issue_body
          text = StringIO.new
          text.puts("#{icon(self)} #{fine? ? 'no ' : ''}active deployment\n\n")

          unless fine?
            text.puts("Production environment locked: There's an active production deployment, see the [deployer pipeline](#{pipeline_url})")
          end

          text.string
        end

        def pipeline_url
          chef_client.pipeline_url
        end

        def production_env
          ::ReleaseTools::PublicRelease::Release::PRODUCTION_ENVIRONMENT
        end

        def chef_client
          @chef_client ||= ::ReleaseTools::Chef::Client.new(production_env)
        end
      end
    end
  end
end
