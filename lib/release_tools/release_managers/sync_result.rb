# frozen_string_literal: true

module ReleaseTools
  module ReleaseManagers
    class SyncResult
      def initialize(clients)
        @clients = clients
      end

      def success?
        errors.empty?
      end

      def formatted_error_message
        return "" if success?

        lines = []

        clients.each do |client|
          next if client.sync_errors.empty?

          lines << "--> Errors syncing to #{client.target}:"
          lines += errors.map { |error| "    #{error.message}" }
        end

        lines.join("\n")
      end

      private

      attr_accessor :clients

      def errors
        @errors ||= clients.flat_map(&:sync_errors)
      end
    end
  end
end
