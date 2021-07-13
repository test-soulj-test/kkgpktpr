# frozen_string_literal: true

module ReleaseTools
  module Tasks
    module Helper
      def get_version(args)
        version = ReleaseTools::Version.new(args[:version])

        unless version.valid?
          $stdout.puts "Version number must be in the following format: X.Y.Z-rc1 or X.Y.Z".colorize(:red)
          exit 1
        end

        version
      end

      def dry_run?
        ReleaseTools::SharedStatus.dry_run?
      end

      def skip?(repo)
        ENV[repo.upcase] == 'false'
      end

      def create_or_show_issuable(issuable)
        if dry_run?
          $stdout.puts
          $stdout.puts "# #{issuable.title}"
          $stdout.puts
          $stdout.puts issuable.description
        elsif issuable.exists?
          issuable.status = :exists

          $stdout.puts "--> #{issuable.type} \"#{issuable.title}\" already exists.".red
          $stdout.puts "    #{issuable.url}"

          ReleaseTools::Slack::ChatopsNotification.release_issue(issuable)
        elsif issuable.create?
          issuable.create
          issuable.status = :created
          issuable.link!

          $stdout.puts "--> #{issuable.type} \"#{issuable.title}\" created.".green
          $stdout.puts "    #{issuable.url}"

          ReleaseTools::Slack::ChatopsNotification.release_issue(issuable)
        else
          $stdout.puts 'No QA issue has to be created'
        end
      end

      def create_or_show_issue(issue)
        create_or_show_issuable(issue)
      end

      def create_or_show_merge_request(merge_request)
        create_or_show_issuable(merge_request)
      end

      def cherry_pick_result(result)
        if result.success?
          "✓ #{result.url}"
        else
          "✗ #{result.url}"
        end
      end

      def build_qa_issue(version, from, to)
        issue = ReleaseTools::Qa::Services::BuildQaIssueService.new(
          version: version,
          from: from,
          to: to,
          projects: ReleaseTools::Qa::PROJECTS
        ).execute

        create_or_show_issue(issue)

        if ENV['RELEASE_ENVIRONMENT'] && issue.status == :exists
          issue.add_comment(<<~MSG)
            :robot: The changes listed in this issue have been deployed
            to `#{ENV['RELEASE_ENVIRONMENT']}`.
          MSG
        end

        issue
      end
    end
  end
end
