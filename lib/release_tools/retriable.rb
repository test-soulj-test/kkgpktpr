# frozen_string_literal: true

require 'retriable'

Retriable.configure do |config|
  config.contexts[:api] = {
    on: [
      ::Gitlab::Error::ResponseError,
      Timeout::Error,
      Errno::ECONNRESET
    ]
  }

  # Retry with exponential backoff, for a maximum of ~5 minutes
  #
  # Ideal for waiting for a pipeline to be created.
  config.contexts[:pipeline_created] = {
    base_interval: 5,
    tries: 10
  }

  # Retry every 60 seconds up to 30 times, for a maximum of 30 minutes
  #
  # Ideal for waiting for a running packager pipeline to complete.
  config.contexts[:package_pipeline] = {
    base_interval: 60,
    tries: 30,
    max_elapsed_time: 30 * 60,  # The maximum amount of total time in seconds that code is allowed to keep being retried
    rand_factor: 0
  }
end
