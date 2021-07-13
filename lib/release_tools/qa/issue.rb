# frozen_string_literal: true

module ReleaseTools
  module Qa
    class Issue < ReleaseTools::Issue
      def title
        "#{version} QA Issue"
      end

      def confidential?
        # Because auto-deploy branches always exist on the Security fork, we
        # can't distinguish between a regular and security release, so default
        # to confidential for safety.
        true
      end

      def labels
        'QA task'
      end

      def add_comment(message)
        ReleaseTools::GitlabClient
          .create_issue_note(project, issue: remote_issuable, body: message)
      end

      def link!
        parent = parent_issue

        ReleaseTools::GitlabClient.link_issues(self, parent) if parent.exists?
      end

      def create?
        merge_requests.any?
      end

      # Returns the appropriate test instance depending on the version supplied
      def gitlab_test_instance
        if auto_deploy_version?
          'https://staging.gitlab.com'
        elsif package_version?
          'https://release.gitlab.net'
        else
          'https://pre.gitlab.com'
        end
      end

      def parent_issue
        # For auto-deploy QA issues we can't use the raw version, as there is no
        # monthly release issue for auto-deploy versions. To handle this we
        # always convert the input version to a MAJOR.MINOR version.
        ReleaseTools::PatchIssue.new(version: Version.new(version.to_minor))
      end

      protected

      def template_path
        File.expand_path('../../../templates/qa.md.erb', __dir__)
      end

      def issue_presenter
        ReleaseTools::Qa::IssuePresenter
          .new(merge_requests, self, version)
      end

      def auto_deploy_version?
        version.match?(ReleaseTools::Qa::Ref::AUTO_DEPLOY_TAG_REGEX)
      end

      def package_version?
        Version.new(version).release?
      end
    end
  end
end
