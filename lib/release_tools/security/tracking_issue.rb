# frozen_string_literal: true

require 'date'

module ReleaseTools
  module Security
    class TrackingIssue < ReleaseTools::Issue
      include ::SemanticLogger::Loggable

      DEFAULT_DUE_DATE_DAY = 28

      CRITICAL_RELEASE_LABEL = 'critical security release'

      def close_outdated_issues
        issues = GitlabClient
          .issues(
            project,
            labels: base_labels,
            per_page: 100,
            state: 'opened',
            confidential: confidential?
          )
          .auto_paginate

        Parallel.each(issues, in_threads: Etc.nprocessors) do |issue|
          logger.info("Closing security tracking issue #{issue.web_url}")

          next if SharedStatus.dry_run?

          has_crit_label = issue.labels.include?(CRITICAL_RELEASE_LABEL)

          # Critical security issues are only closed for critical releases,
          # while regular security issues are only closed for regular releases.
          next if has_crit_label != SharedStatus.critical_security_release?

          GitlabClient.close_issue(project, issue)
        end
      end

      def title
        prefix =
          if SharedStatus.critical_security_release?
            'Critical security'
          else
            'Security'
          end

        "#{prefix} release: #{versions_title}"
      end

      def confidential?
        true
      end

      def labels
        labels = base_labels

        if SharedStatus.critical_security_release?
          labels += ",#{CRITICAL_RELEASE_LABEL}"
        end

        labels
      end

      def base_labels
        'upcoming security release,security'
      end

      def project
        ReleaseTools::Project::GitlabEe
      end

      def versions_title
        upcoming_security_versions.map! do |version|
          version.sub(/\d+$/, 'x')
        end.join(', ')
      end

      # Regular Security Releases are performed in the next milestone
      # of the last version released, e.g if the last version released is 13.6,
      # the Security Release will be performed on %13.7.
      def version
        next_minor = ReleaseTools::Version.new(next_version).next_minor

        ReleaseTools::Version.new(next_minor)
      end

      def due_date
        current_date = Date.today

        # due_date_month depends on the date the security release was completed,
        # this one can be wrapped up on the 28th, but it can also be completed
        # the first week of the next month, e.g. if it's completed on Nov 28th
        # the next due date will be Dec 28th, but if it's completed on Dec 2nd,
        # the due date still needs to be Dec 28th.
        due_date_month = if current_date.day < 10
                           current_date.month
                         else
                           current_date.next_month.month
                         end

        Date.new(current_date.year, due_date_month, DEFAULT_DUE_DATE_DAY).to_s
      end

      def assignees
        ReleaseManagers::Schedule.new.active_release_managers.collect(&:id)
      rescue ReleaseManagers::Schedule::VersionNotFoundError
        nil
      end

      protected

      def template_path
        File.expand_path('../../../templates/security_release_tracking_issue.md.erb', __dir__)
      end

      def security_versions
        @security_versions ||= ReleaseTools::Versions.next_security_versions.take(2)
      end

      def next_version
        @next_version ||= ReleaseTools::Version.new(security_versions.first).next_minor
      end

      def upcoming_security_versions
        [next_version] + security_versions
      end
    end
  end
end
