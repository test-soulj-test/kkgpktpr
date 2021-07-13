# frozen_string_literal: true

module ReleaseTools
  module Prometheus
    class Query
      include ::SemanticLogger::Loggable
      class PromQLError < StandardError
        attr_reader :status_code, :body

        def initialize(status_code, body)
          @status_code = status_code
          @body = body
        end

        def to_s
          "API failure. Status code: #{status_code}, body: #{body}"
        end
      end

      ENDPOINT = "http://#{ENV['PROMETHEUS_HOST']}/api/v1/query"
      ROLE_VERSIONS = {
        'gprd' => 'tier="sv", env="gprd", stage="main"',
        'gprd-cny' => 'tier="sv", env="gprd", stage="cny"',
        'gstg' => 'tier="sv", env="gstg"'
      }.freeze

      def run(query)
        logger.trace('PromQL query', query: query)

        response = HTTP.get(ENDPOINT, params: { query: query })

        unless response.status.success?
          error = PromQLError.new(response.status.code, response.body.to_s)
          logger.warn('API Failure', status: error.status_code.to_s, error: error.body)

          raise error
        end

        response.parse
      end

      def rails_version_by_role
        return {} unless ENV['PROMETHEUS_HOST']

        ROLE_VERSIONS.each_with_object({}) do |(role, params), memo|
          query = "topk(1, count(omnibus_build_info{#{params}}) by (version))"
          begin
            response = run(query)

            # jq '.data .result | .[] | .metric'
            metric = response.dig('data', 'result', 0, 'metric')
            next memo[role] = '' if metric.nil?

            # FIXME (rspeicher): https://gitlab.com/gitlab-org/release-tools/-/issues/448
            version = ReleaseTools::Qa::Ref.new(metric['version'])
            memo[role] = version.ref
          rescue PromQLError
            next memo[role] = ''
          end
        end
      end
    end
  end
end
