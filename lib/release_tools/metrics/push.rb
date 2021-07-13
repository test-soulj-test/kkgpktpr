# frozen_string_literal: true

module ReleaseTools
  module Metrics
    # Interface to a Prometheus Pushgateway
    #
    # https://prometheus.io/docs/instrumenting/pushing/
    class Push
      GATEWAY = ENV['PUSHGATEWAY_URL']

      def initialize(job)
        # Normalize `delivery_foo_bar` into `foo-bar`
        job = job.to_s
          .tr('_', '-')
          .delete_prefix('delivery-')

        @push = ::Prometheus::Client::Push
          .new(job, nil, GATEWAY) # job, instance, gateway
      end

      def replace(registry)
        @push.replace(registry)
      end
    end
  end
end
