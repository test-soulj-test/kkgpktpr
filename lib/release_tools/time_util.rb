# frozen_string_literal: true

module ReleaseTools
  module TimeUtil
    extend self

    def timeout?(start, max_duration)
      Time.now.to_i > (start + max_duration)
    end

    def time_ago(time, precision: 1)
      return unless time

      ago = duration((Time.now - time).to_i)
      short = ago.take(precision).join(', ')
      "#{short} ago"
    end

    def duration(delta)
      result = []

      [[60, 'second'],
       [60, 'minute'],
       [24, 'hour'],
       [365, 'day'],
       [999, 'year']]
        .inject(delta) do |length, (divisor, name)|
          quotient, remainder = length.divmod(divisor)
          period = remainder == 1 ? name : name.pluralize
          result.unshift("#{remainder} #{period}")
          break if quotient.zero?

          quotient
        end

      result
    end
    private_class_method :duration
  end
end
