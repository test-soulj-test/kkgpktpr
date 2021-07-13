# frozen_string_literal: true

module ReleaseTools
  module Tasks
    module AutoDeploy
      class Tag
        include ::SemanticLogger::Loggable

        attr_reader :branch, :version

        def initialize
          @branch = ReleaseTools::AutoDeployBranch.current
          @version = ReleaseTools::AutoDeploy::Tag.current
        end

        def metadata
          @metadata ||= prepopulate_metadata
        end

        def execute
          notify
          find_passing_build

          omnibus_changes = build_omnibus
          cng_changes = build_cng
          tag_coordinator if omnibus_changes || cng_changes

          return unless ReleaseTools::AutoDeploy.coordinator_pipeline?

          store_deploy_version
          sentry_release
          upload_metadata
        end

        def notify
          return unless ReleaseTools::AutoDeploy.coordinator_pipeline?

          ReleaseTools::Slack::Message.post(
            channel: ReleaseTools::Slack::F_UPCOMING_RELEASE,
            message: "New coordinated pipeline: <#{ENV['CI_PIPELINE_URL']}|#{version}> (`#{branch}` @ `#{commit.id[0...11]}`)",
            mrkdwn: true
          )
        end

        def find_passing_build
          logger.info('Searching for commit with passing build', branch: branch.to_s)
          commit
        end

        def build_omnibus
          logger.info('Building Omnibus', commit: commit.id)
          ReleaseTools::AutoDeploy::Builder::Omnibus
            .new(branch, commit.id, metadata)
            .execute
        end

        def build_cng
          logger.info('Building CNG', commit: commit.id)
          ReleaseTools::AutoDeploy::Builder::CNGImage
            .new(branch, commit.id, metadata)
            .execute
        end

        def tag_coordinator
          ReleaseTools::AutoDeploy::Tagger::Coordinator.new.tag!
        end

        def sentry_release
          ReleaseTools::Deployments::SentryTracker.new.release(commit.id)
        end

        def upload_metadata
          ReleaseTools::ReleaseMetadataUploader.new.upload(version, metadata)
        end

        def store_deploy_version
          return if SharedStatus.dry_run?

          logger.info('Storing deploy version', deploy_version: deploy_version)

          File.open('deploy_vars.env', 'w') do |deploy_vars|
            deploy_vars.write("DEPLOY_VERSION=#{deploy_version}")
          end
        end

        private

        def prepopulate_metadata
          klass = ReleaseTools::ReleaseMetadata

          return klass.new unless ReleaseTools::AutoDeploy.coordinator_pipeline?

          # NOTE: We need to use the *previous* tag, not the latest one, because
          # the latest one is the one we're running on
          tag = Retriable.with_context(:api) do
            GitlabOpsClient.tags(Project::ReleaseTools, per_page: 2).last
          end

          metadata = GitlabOpsClient.release_metadata(Version.new(tag.name))

          klass.new.tap do |instance|
            metadata['releases']&.each do |name, data|
              instance.add_release(name: name, **data)
            end
          end
        end

        def commit
          @commit ||= ReleaseTools::PassingBuild.new(branch.to_s).execute
        end

        def deploy_version
          @deploy_version ||= metadata
            .releases['omnibus-gitlab-ee']
            .ref
            .tr('+', '-')
        end
      end
    end
  end
end
