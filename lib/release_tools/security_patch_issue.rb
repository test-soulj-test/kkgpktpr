# frozen_string_literal: true

module ReleaseTools
  class SecurityPatchIssue < PatchIssue
    def title
      if regular?
        "Security patch release: #{versions_title}"
      else
        "Critical security patch release: #{versions_title}"
      end
    end

    def confidential?
      true
    end

    def labels
      "#{super},security"
    end

    def critical?
      ReleaseTools::SharedStatus.critical_security_release?
    end

    def regular?
      !critical?
    end

    def version
      ReleaseTools::Versions.latest(versions, 1).first
    end

    def informative_title
      if regular?
        'GitLab Security Release'
      else
        'GitLab Critical Security Release'
      end
    end

    protected

    def template_path
      File.expand_path('../../templates/security_patch.md.erb', __dir__)
    end

    def versions_title
      versions.join(', ')
    end
  end
end
