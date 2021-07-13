# frozen_string_literal: true

require 'http'

module ReleaseTools
  module Deployments
    # Track Sentry Releases and Deployments
    #
    # See https://docs.sentry.io/workflow/releases/
    # and https://blog.sentry.io/2017/05/09/release-deploys
    class SentryTracker
      include ::SemanticLogger::Loggable

      API_ENDPOINT = 'https://sentry.gitlab.net/api/0/organizations/gitlab/releases/'
      SHA_RANGE = (0...11).freeze

      def release(sha)
        return if SharedStatus.dry_run?
        return unless new_release?(sha[SHA_RANGE])

        params = {
          version: sha[SHA_RANGE],
          refs: [
            {
              repository: 'GitLab.org / security / 🔒 gitlab',
              commit: sha
            }
          ],
          projects: %w[gitlabcom staginggitlabcom]
        }

        logger.info('Creating Sentry release', version: params[:version])
        client.post(API_ENDPOINT, json: params)
      end

      # Create a new Deploy
      #
      # environment - environment string (gprd, gprd-cny, gstg)
      # version - auto-deploy version (e.g., `13.1.202006091440-ede0c8ff414.008fd19283c`)
      def deploy(environment, status, version)
        return if SharedStatus.dry_run?
        return unless status == 'success'

        sha = ReleaseTools::Qa::Ref.new(version).ref
        now = Time.now.utc.iso8601

        params = {
          environment: environment,
          dateStarted: now,
          dateFinished: now
        }

        logger.info('Creating Sentry deploy', version: sha, environment: environment)
        client.post("#{API_ENDPOINT}#{sha}/deploys/", json: params)
      end

      private

      def token
        @token ||= ENV.fetch('SENTRY_AUTH_TOKEN') do |name|
          raise "Missing environment variable `#{name}`"
        end
      end

      def client
        @client ||= HTTP.auth("Bearer #{token}")
      end

      def new_release?(sha)
        client.get("#{API_ENDPOINT}#{sha}/").status.not_found?
      end
    end
  end
end
