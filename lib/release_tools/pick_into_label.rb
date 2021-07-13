# frozen_string_literal: true

module ReleaseTools
  class PickIntoLabel
    include ::SemanticLogger::Loggable

    GROUP = 'gitlab-org'
    COLOR = '#00C8CA'
    DESCRIPTION = 'Merge requests to cherry-pick into the `%s` branch.'

    # Create a group label for the specified version
    def self.create(version)
      new(version).create
    end

    def self.escaped(version)
      CGI.escape(self.for(version))
    end

    def self.for(version)
      if version == :auto_deploy
        "Pick into auto-deploy"
      else
        "Pick into #{version.to_minor}"
      end
    end

    def self.reference(version)
      %[~"#{self.for(version)}"]
    end

    def initialize(version)
      @version = version
      @label = self.class.for(@version)
    end

    def create
      logger.info("Creating monthly Pick label", label: @label)

      return if ReleaseTools::SharedStatus.dry_run?

      GitlabClient.create_group_label(
        GROUP,
        @label,
        COLOR,
        description: DESCRIPTION % @version.stable_branch
      )
    rescue Gitlab::Error::Conflict, Gitlab::Error::BadRequest => ex
      # The GitLab API is inconsistent about which error code it responds with
      # in this situation, but either way if it's an "already exists" error,
      # just swallow it for idempotency
      raise unless ex.message.match?('already exists')
    end
  end
end
