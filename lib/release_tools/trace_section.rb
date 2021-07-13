# frozen_string_literal: true

module ReleaseTools
  module TraceSection
    def self.collapse(summary, icon: nil)
      title =
        if icon
          "#{icon} #{summary}"
        else
          summary
        end

      section = section_name(summary)

      puts "section_start:#{Time.now.to_i}:#{section}[collapsed=true]\r\e[0K#{title}"

      ret = yield

      close(section)
      ret
    rescue StandardError => ex
      close(section)

      # If we don't handle the error, it's displayed within the collapsed
      # section, which can be confusing. Handling the error allows us to close
      # the section first, and display it outside of the section.
      puts "❌ The section #{summary.inspect} produced an error:".colorize(:red)
      raise ex
    end

    def self.close(section)
      # Flush any output so we capture it in the section, instead of it being
      # buffered and displayed outside of the section.
      #
      # We flush here so that for both the happy and error path we flush the
      # output first.
      $stdout.flush
      $stderr.flush
      SemanticLogger.flush

      puts "section_end:#{Time.now.to_i}:#{section}\r\e[0K"
    end

    def self.section_name(summary)
      summary.downcase.tr(':', '-').gsub(/\s+/, '_')
    end
  end
end
