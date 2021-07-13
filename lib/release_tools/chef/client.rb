# frozen_string_literal: true

require 'chef-api'

module ReleaseTools
  module Chef
    class Client
      attr_reader :environment

      REQUIRED_ENV = %w[CHEF_API_KEY CHEF_API_ENDPOINT CHEF_API_CLIENT].freeze

      def initialize(environment)
        unless REQUIRED_ENV.all? { |s| ENV.key?(s) }
          raise "You must set #{REQUIRED_ENV.join(',')} as env variables to connect to Chef"
        end

        @environment = environment
        @connection = ChefAPI::Connection.new
      end

      def environment_enabled?
        enabled = omnibus_role
                    .default_attributes
                    .dig('omnibus-gitlab', 'package', 'enable')
        return true if enabled.nil?

        enabled
      end

      def pipeline_url
        omnibus_role
          .default_attributes
          .dig('omnibus-gitlab', 'package', '__CI_PIPELINE_URL') || 'unknown'
      end

      private

      def omnibus_role
        @omnibus_role ||= @connection.roles.fetch("#{environment}-omnibus-version")
      end
    end
  end
end
