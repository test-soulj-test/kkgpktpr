# frozen_string_literal: true

module ReleaseTools
  module SharedStatus
    extend self

    def dry_run?
      !ENV.fetch('TEST', 'false').casecmp?('false')
    end

    def critical_security_release?
      ENV['SECURITY'] == 'critical'
    end

    def security_release?
      return true if ENV['SECURITY'].present?

      @security_release == true
    end

    # rubocop:disable Style/OptionalBooleanParameter
    def as_security_release(security_release = true)
      @security_release = security_release
      yield
    ensure
      @security_release = false
    end
    # rubocop:enable Style/OptionalBooleanParameter

    def user
      `git config --get user.name`.strip
    end
  end
end
