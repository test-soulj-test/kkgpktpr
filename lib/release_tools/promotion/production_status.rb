# frozen_string_literal: true

module ReleaseTools
  module Promotion
    # Perform production checks and report on their statuses
    #
    # There is a default group of checks that are always queried. Additional
    # checks can be included by passing them to the initializer:
    #
    #   # Additionally include `MyCustomCheck` and `ConditionalCheck`
    #   ProductionStatus.new(:my_custom_check, :conditional_check)
    class ProductionStatus
      include ::SemanticLogger::Loggable
      include Check

      # Raised when attempting to include an unknown `Check` class
      class InvalidCheckError < StandardError
        def initialize(name)
          super("Unknown check `#{name}`")
        end
      end

      # List of checks that are always included for any production status check
      ALL_CHECKS = %i[
        active_incidents
        change_requests
        gitlab_deployment_health
      ].freeze

      attr_reader :checks

      # TODO (rspeicher): Remove skip_active_deployment_check parameter
      def initialize(*extra_checks, skip_active_deployment_check: false)
        @checks = [*ALL_CHECKS, *extra_checks].uniq.map do |check_name|
          instance_of_check(check_name)
        end

        # TODO (rspeicher): Handle this at the call sites needing this check
        @checks << instance_of_check(:active_deployments) unless skip_active_deployment_check
      end

      # @see Check#fine?
      def fine?
        checks.all?(&:fine?)
      end

      # @see Check#to_issue_body
      def to_issue_body
        text = StringIO.new
        if fine?
          labels = Checks::ActiveIncidents::BLOCKING_LABELS.map { |l| "~#{l}" }
          text.puts(
            "#{ok_icon} Production has no active #{labels.join(' / ')} incidents or in-progress change issues."
          )
        else
          text.puts("#{failure_icon} Production checks fail because there are blockers")
        end

        checks.each do |check|
          text.puts("\n---")
          text.puts(check.to_issue_body)
        end

        text.string
      end

      # @see Check#to_slack_block
      def to_slack_block(status)
        {
          type: 'section',
          text: mrkdwn(status)
        }
      end

      def to_slack_blocks
        overall_status = if fine?
                           "#{ok_icon} Production checks pass! :shipit: :fine:"
                         else
                           "#{failure_icon} Production checks fail!"
                         end

        if fine?
          [to_slack_block(overall_status)]
        else
          [to_slack_block(overall_status)] + checks.reject(&:fine?).map(&:to_slack_blocks).flatten
        end
      end

      private

      def instance_of_check(check_name)
        Checks.const_get(check_name.to_s.camelize).new
      rescue NameError => ex
        raise InvalidCheckError, ex.name
      end
    end
  end
end
