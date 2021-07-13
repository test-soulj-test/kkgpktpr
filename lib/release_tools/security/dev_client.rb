# frozen_string_literal: true

module ReleaseTools
  module Security
    # A GitLab API client to use when validating security merge requests on Dev
    class DevClient < Client
      def initialize
        @gitlab_client = ReleaseTools::GitlabDevClient.client
      end
    end
  end
end
