# frozen_string_literal: true

module ReleaseTools
  module Qa
    class IssuePresenter
      attr_reader :merge_requests, :issue, :version

      def initialize(merge_requests, issue, version)
        @merge_requests = merge_requests
        @issue = issue
        @version = version
      end

      def present
        (+"").tap do |text|
          if issue.exists?
            text << issue.remote_issuable.description
          else
            text << header_text
          end
          text << formatter.lines.join("\n")
          text << automated_qa_text
        end
      end

      private

      def header_text
        <<~HEREDOC
          ## Escalating high severity regressions

          If you discover a high severity regression (~"severity::1" or ~"severity::2") on [#{issue.gitlab_test_instance}](#{issue.gitlab_test_instance}/users/sign_in), based on the [Availability Severity definitions](https://about.gitlab.com/handbook/engineering/quality/issue-triage/#availability) take immediate action:

          1. Follow the steps to [block the deployment](https://about.gitlab.com/handbook/engineering/releases/#deployment-blockers)


          <details>
            <summary>Click for detailed process instructions</summary>

          ## Process

          Each engineer validates each of their assigned QA task(s).
          1. Test each Merge Request change and note any issues you've created.
          1. If a problem is found:
              * Create an issue for it and add a sub bullet item under the corresponding validation task. Link the issue there.
              * Add the severity label
              * Raise the problem in the discussion and tag relevant Engineering and Product managers.
          1. If a regression is found:
              * Create an issue for it
              * Add the severity label and the regression label
              * Raise the regression in the discussion and tag relevant Engineering and Product managers.

          General Quality info can be found in the [Quality Handbook](https://about.gitlab.com/handbook/engineering/quality/).

          Note: If you are assigned tasks outside your normal work hours, you're not expected to work overtime. Please complete the tasks as soon
          as possible during your normal work hours.



          ## Deadline

          QA testing on #{issue.gitlab_test_instance}/users/sign_in for this issue should be completed by **#{due_date.strftime('%Y-%m-%d %H:%M')} UTC**.
          After this deadline has passed, the issue will be closed automatically.

          If the deadline has passed, please perform your task as soon as possible anyway (during your normal work hours). It's important that the testing is
          performed, even if deployment has proceeded to a later stage.

          ## Testing changes requiring admin or console access

          If testing changes requires admin or console access which you might be lacking on #{issue.gitlab_test_instance},
          create a virtual machine locally or using one of the cloud service providers, and install the latest nightly
          package from [packages.gitlab.com/gitlab/nightly-builds](https://packages.gitlab.com/gitlab/nightly-builds).

          ## Testing CE only changes

          When testing changes in CE specifically, use [dev.gitlab.org](https://dev.gitlab.org) as it is running a nightly version of GitLab CE.  If it is determined
          that the dev instance does not suffice, create a virtual machine to install the CE package and complete an install to perform the necessary testing.
          Currently we do not build CE packages to match that of the version in this QA issue.
          The best course of action would be to find the closest CE package from our nightly repository. [packages.gitlab.com/gitlab/nightly-builds](https://packages.gitlab.com/gitlab/nightly-builds)

          ## Testing docs-only community contributions

          Docs-only community contributions do not need to be verified on staging or dev. Simply verify that the change
          is reflected on the relevant page on [docs.gitlab.com](http://docs.gitlab.com).
          </details>

          ## Merge Requests tested in #{version}

        HEREDOC
      end

      def automated_qa_text
        <<~HEREDOC
          ## Automated QA for #{version}\n\n

          The test session report for this deployment is generated in [testcase-sessions project](https://gitlab.com/gitlab-org/quality/testcase-sessions), with the correspoding testcase linked in this issue.

          Once the testcases coverage is satisfactory, we will remove the explicit user @ mention in this issue. Help make that happen quicker by expanding [the end-to-end test suite](https://gitlab.com/gitlab-org/gitlab/-/tree/master/qa).
        HEREDOC
      end

      def sort_merge_requests
        ReleaseTools::Qa::IssuableSortByLabels.new(merge_requests).sort_by_labels(*labels)
      end

      def formatter
        ReleaseTools::Qa::Formatters::MergeRequestsFormatter.new(
          merge_requests: sort_merge_requests,
          project_path: issue.project.path
        )
      end

      def labels
        [ReleaseTools::Qa.group_labels]
      end

      def due_date
        utc_date = DateTime.now.new_offset(0)

        if utc_date.friday?
          utc_date + 72.hours
        elsif utc_date.saturday?
          utc_date + 48.hours
        else
          utc_date + 24.hours
        end
      end
    end
  end
end
