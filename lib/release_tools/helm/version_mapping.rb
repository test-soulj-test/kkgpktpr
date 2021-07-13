# frozen_string_literal: true

module ReleaseTools
  module Helm
    # Parsing and generating of the Markdown table that maps Helm versions to
    # GitLab versions.
    class VersionMapping
      HEADER = '| Chart version | GitLab version |'
      DIVIDER = '|---------------|----------------|'

      # An error that may be produced when parsing a Markdown document.
      ParseError = Class.new(StandardError)

      # A single row in the version mapping table.
      Row = Struct.new(:helm_version, :gitlab_version)

      attr_reader :lines, :rows, :start, :stop

      def self.parse(markdown)
        lines = markdown.split("\n")
        start = lines.index(HEADER)

        if !start || lines[start + 1] != DIVIDER
          raise(ParseError, <<~ERROR.strip)
            The Markdown table is not formatted correctly.

            Markdown tables must start with the following header:

            #{HEADER}
            #{DIVIDER}
          ERROR
        end

        index = start + 2
        rows = []

        while index < lines.length
          line = lines[index].strip

          break if line.empty?

          _, raw_helm_version, raw_gitlab_version = line.split(/\s*\|\s*/)

          # If Helm version is not specified, `raw_helm_version` will be an
          # empty String instead of being nil. If only a Helm version is given,
          # `raw_gitlab_version` _will_ be nil. The to_s conversion below allows
          # us to handle both cases transparently.
          if raw_helm_version.to_s.empty? || raw_gitlab_version.to_s.empty?
            raise(
              ParseError,
              "The row #{line} must contain both a Helm and GitLab version"
            )
          end

          helm_version = Version.new(raw_helm_version)
          gitlab_version = Version.new(raw_gitlab_version)

          rows << Row.new(helm_version, gitlab_version)
          index += 1
        end

        new(lines: lines, rows: rows, start: start, stop: index - 1)
      end

      def initialize(lines:, rows:, start:, stop:)
        # The original lines are frozen to ensure we don't accidentally modify
        # them in place. Doing so could lead to unexpected output being
        # produced.
        @lines = lines.freeze
        @rows = rows
        @start = start
        @stop = stop
      end

      def add(helm_version, gitlab_version)
        existing = rows.find { |row| row.helm_version == helm_version }

        if existing
          existing.gitlab_version = gitlab_version
        else
          rows.push(Row.new(helm_version, gitlab_version))
        end
      end

      def to_s
        new_rows = rows.sort { |a, b| b.helm_version <=> a.helm_version }
        row_lines = new_rows.map do |row|
          "| #{row.helm_version} | #{row.gitlab_version.to_normalized_version} |"
        end

        table = "#{HEADER}\n#{DIVIDER}\n#{row_lines.join("\n")}"

        old_range = start..stop
        new_lines = lines.dup

        # We want to insert _after_ the last line of the table, so we add 1 to
        # the table's end position.
        new_lines.insert(old_range.end + 1, table)

        # This will remove all lines of the old table, leaving the newly
        # inserted table as-is.
        new_lines.reject!.with_index { |_, index| old_range.cover?(index) }

        # The document has a trailing newline. While (not) adding one doesn't
        # really matter, this ensures that any diffs _only_ include the lines
        # that change the mapping table.
        "#{new_lines.join("\n")}\n"
      end
    end
  end
end
