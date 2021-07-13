# frozen_string_literal: true

module ReleaseTools
  module Tasks
    module Release
      class Issue
        include ReleaseTools::Tasks::Helper

        attr_reader :version

        def initialize(version)
          @version = version
        end

        def execute
          issue = if version.monthly?
                    ReleaseTools::MonthlyIssue.new(version: version)
                  else
                    ReleaseTools::PatchIssue.new(version: version)
                  end

          create_or_show_issue(issue)
        end
      end
    end
  end
end
