# frozen_string_literal: true

module ReleaseTools
  class Issue < Issuable
    def create
      ReleaseTools::GitlabClient.create_issue(self, project)
    end

    def update
      ReleaseTools::GitlabClient.update_issue(self, project)
    end

    def remote_issuable
      @remote_issuable ||= ReleaseTools::GitlabClient.find_issue(self, project)
    end

    def confidential?
      false
    end
  end
end
