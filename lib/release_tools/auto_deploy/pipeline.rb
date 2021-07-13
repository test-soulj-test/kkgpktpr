# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    module Pipeline
      # If a pipeline has one of these statuses, we'll wait on it
      WAITING_STATUSES = %w[
        created
        waiting_for_resource
        preparing
        pending
        running
        scheduled
      ].freeze

      # If a pipeline has one of these statuses, we consider it failed
      FAILURE_STATUSES = %w[
        failed
        canceled
        skipped
        manual
      ].freeze

      class PipelineError < StandardError
        attr_reader :pipeline

        def initialize(message, pipeline)
          super(message)
          @pipeline = pipeline
        end
      end

      class MissingPipelineError < PipelineError
        def initialize(pipeline = nil)
          super('Pipeline for packager is missing', pipeline)
        end
      end

      class RunningPipelineError < PipelineError
        def initialize(pipeline)
          super('Pipeline for packager is still running', pipeline)
        end
      end

      class FailedPipelineError < PipelineError
        def initialize(pipeline)
          super('Pipeline for packager was not successful', pipeline)
        end
      end
    end
  end
end
