# frozen_string_literal: true

module ReleaseTools
  class PatchIssue < Issue
    def title
      "Release #{version.to_ce}"
    end

    def labels
      'Monthly Release'
    end

    def project
      ReleaseTools::Project::Release::Tasks
    end

    def monthly_issue
      @monthly_issue ||= ReleaseTools::MonthlyIssue.new(version: version)
    end

    def link!
      return if version.monthly?

      ReleaseTools::GitlabClient.link_issues(self, monthly_issue)
    end

    def assignees
      ReleaseManagers::Schedule.new.active_release_managers.collect(&:id)
    rescue ReleaseManagers::Schedule::VersionNotFoundError
      nil
    end

    protected

    def template_path
      if version.rc?
        File.expand_path('../../templates/release_candidate.md.erb', __dir__)
      else
        File.expand_path('../../templates/patch.md.erb', __dir__)
      end
    end
  end
end
