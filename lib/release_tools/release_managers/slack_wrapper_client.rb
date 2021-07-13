# frozen_string_literal: true

require 'http'

module ReleaseTools
  module ReleaseManagers
    # A client for https://ops.gitlab.net/gitlab-com/gl-infra/infra-automation-commons/slack-wrapper
    class SlackWrapperClient
      include ::SemanticLogger::Loggable

      attr_reader :sync_errors, :token, :endpoint

      # Initialize a slack-wrapper API client specific to Release Manager tasks
      def initialize
        @endpoint = ENV.fetch('SLACK_WRAPPER_URL') do |name|
          raise "Missing environment variable `#{name}`"
        end

        @token = ENV.fetch('SLACK_WRAPPER_TOKEN') do |name|
          raise "Missing environment variable `#{name}`"
        end

        @sync_errors = []
      end

      def sync_membership(user_ids)
        url = File.join(user_group_update_url, user_ids.join(','))
        logger.info('Syncing membership', user_ids: user_ids, url: url)

        response = HTTP.auth("Bearer #{@token}").post(url)
        return if response.status.success?

        sync_errors << case response.status.to_sym
                       when :unauthorized
                         Client::UnauthorizedError.new("Unauthorized")
                       when :forbidden
                         Client::UnauthorizedError.new('Invalid token')
                       else
                         Client::SyncError.new(response.status.reason)
                       end
      end

      private

      def user_group_update_url
        File.join(endpoint, 'usergroups.users.update', ReleaseTools::Slack::RELEASE_MANAGERS)
      end
    end
  end
end
