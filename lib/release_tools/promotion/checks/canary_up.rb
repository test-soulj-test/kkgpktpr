# frozen_string_literal: true

module ReleaseTools
  module Promotion
    module Checks
      class CanaryUp
        include ::ReleaseTools::Promotion::Check
        include ::SemanticLogger::Loggable

        # We're counting the number of "rows" with the value of 0 (meaning they're not up).
        # We don't care what that count is beyond "does this query return anything"
        # if it's empty, none are down;
        # if it's not empty, at least one is down and we should fire a warning.
        QUERY = 'count(haproxy_backend_up{env="gprd", backend=~"canary_.*"} == 0)'

        def initialize
          @prometheus = ReleaseTools::Prometheus::Query.new
        end

        def fine?
          return true unless ReleaseTools::Feature.enabled?(:check_canary_up)

          canary_up?
        end

        def to_slack_blocks
          [{ type: 'section', text: mrkdwn(status_message) }]
        end

        def to_issue_body
          status_message
        end

        private

        def status_message
          "#{icon(self)} Canary is #{fine? ? 'up' : 'down'}"
        end

        def canary_up?
          return @canary_up if defined?(@canary_up)

          @canary_up =
            begin
              response = @prometheus.run(QUERY)

              logger.trace('Prometheus response', response: response)

              response.dig('data', 'result').empty?
            rescue StandardError => ex
              logger.fatal('Failed checking Canary status', ex)

              false
            end
        end
      end
    end
  end
end
