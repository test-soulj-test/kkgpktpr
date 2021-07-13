# frozen_string_literal: true

module ReleaseTools
  # Represents an auto-deploy branch for purposes of cherry-picking
  class AutoDeployBranch
    attr_reader :version, :branch_name, :date

    # Return the current auto-deploy branch name from environment variable
    def self.current_name
      ENV.fetch('AUTO_DEPLOY_BRANCH')
    end

    def self.current
      new(current_name)
    end

    def initialize(name)
      major, minor, _, _, date = name.split('-')

      @version = Version.new("#{major}.#{minor}")
      @branch_name = name
      @date = date
    end

    def to_s
      branch_name
    end
  end
end
