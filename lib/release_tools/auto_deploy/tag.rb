# frozen_string_literal: true

module ReleaseTools
  module AutoDeploy
    class Tag
      include ::SemanticLogger::Loggable

      # We purposefully want this to be defined at runtime
      NOW = Time.now.utc.freeze

      # Return the current auto-deploy tag string
      #
      # If a manually-specified tag is available, that will be used first.
      #
      # If running on a tagged release-tools pipeline, this will simply return
      # that tag.
      #
      # Otherwise, we build the tag string from the current auto-deploy branch
      # and the current UTC timestamp.
      def self.current
        ENV.fetch('AUTO_DEPLOY_TAG') do
          ENV.fetch('CI_COMMIT_TAG') do
            new.to_s
          end
        end
      end

      def initialize
        @branch = ReleaseTools::AutoDeployBranch.current
      end

      def to_s
        "#{@branch.version.to_minor}.#{timestamp}"
      end

      def timestamp
        NOW.strftime('%Y%m%d%H%M')
      end

      def omnibus_package
        component_ref(component: 'omnibus-gitlab-ee').sub('+', '-')
      end

      def component_ref(component:)
        release_metadata.dig('releases', component, 'ref')
      end

      def release_metadata
        @release_metadata ||=
          begin
            version = ReleaseTools::Version.new(self.class.current)

            logger.info('Fetching release metadata', version: version)

            ReleaseTools::GitlabOpsClient.release_metadata(version)
          end
      end
    end
  end
end
