# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    class Naming
      BRANCH_FORMAT = '%<major>d-%<minor>d-auto-deploy-%<timestamp>s'

      def self.branch
        new.branch
      end

      def branch
        format(
          BRANCH_FORMAT,
          major: version.major,
          minor: version.minor,
          timestamp: Time.now.strftime('%Y%m%d%H')
        )
      end

      def version
        @version ||= ReleaseManagers::Schedule.new.active_version
      end
    end
  end
end
