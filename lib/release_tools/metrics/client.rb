# frozen_string_literal: true

module ReleaseTools
  module Metrics
    # Interface to delivery-metrics Pushgateway
    class Client
      include ::SemanticLogger::Loggable

      GATEWAY = ENV['DELIVERY_METRICS_URL']
      TOKEN = ENV['DELIVERY_METRICS_TOKEN']

      def initialize
        @client = HTTP.headers("X-Private-Token": TOKEN)
      end

      def observe(metric, value, labels: "")
        response = @client.post("#{url_for(metric)}/observe",
                                form: {
                                  value: value,
                                  labels: labels
                                })
        return if response.status.success?

        logger.error('Recording metric failed', metric: metric, http_status: response.status.code, message: response.body.to_s)
      end

      private

      def url_for(metric)
        "#{GATEWAY}/api/#{metric}"
      end
    end
  end
end
