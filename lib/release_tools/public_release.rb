# frozen_string_literal: true

module ReleaseTools
  module PublicRelease
    # Parses a String in the format `key=value,key=value` into a Hash.
    def self.parse_hash_from_string(string)
      pairs = string.split(',').map { |chunk| chunk.split('=') }

      Hash[pairs].transform_keys(&:to_sym)
    end
  end
end
