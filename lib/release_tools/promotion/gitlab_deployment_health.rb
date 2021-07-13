# frozen_string_literal: true

module ReleaseTools
  module Promotion
    class GitlabDeploymentHealth
      QUERY = 'gitlab_deployment_health:service{env="gprd", type!="registry"}'
      INSTANT_VECTOR_VALUE_IDX = 1

      Service = Struct.new(:type, :stage, :fine?) do
        def name
          "#{stage}-#{type}"
        end
      end

      def services
        query_result.map do |result|
          stage = result.dig('metric', 'stage')
          type = result.dig('metric', 'type')
          value = result.dig('value', INSTANT_VECTOR_VALUE_IDX).to_i

          Service.new(type, stage, value == 1)
        end
      end

      private

      def run_query
        Retriable.retriable do
          ReleaseTools::Prometheus::Query.new.run(QUERY)
        end
      end

      # query_results returns instant vectors, the metric is designed as a boolean.
      # A value of 1 means ok, 0 means troubles.
      #
      # Relevant labels:
      #  stage: the application stage, i.e. `cny` or `main`
      #  type: the node type, i.e. `api`, `git`, `web`, `sidekiq`
      def query_result
        @query_result ||= run_query['data'].fetch('result', [])
      end
    end
  end
end
