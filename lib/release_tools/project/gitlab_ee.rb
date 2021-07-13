# frozen_string_literal: true

module ReleaseTools
  module Project
    class GitlabEe < BaseProject
      REMOTES = {
        canonical: 'git@gitlab.com:gitlab-org/gitlab.git',
        dev:       'git@dev.gitlab.org:gitlab/gitlab-ee.git',
        security:  'git@gitlab.com:gitlab-org/security/gitlab.git'
      }.freeze

      # Patterns to use for extracting Gem versions from the EE Gemfile.lock
      # file.
      #
      # The keys should be readable names, but don't necessarily have to match
      # the Gem name. The values are regular expressions.
      GEM_PATTERNS = {
        mailroom: /^(gitlab-)?mail_room$/
      }.freeze

      # Returns a Hash of `gem_name => variable_name` pairs
      # Gem names are regular expressions to allow for renames
      # and backwards compatibility
      #
      # The variables are used in CNG image configurations.
      def self.gems
        {
          GEM_PATTERNS[:mailroom] => 'MAILROOM_VERSION'
        }
      end

      def self.default_branch
        if Feature.enabled?(:switch_to_main_branch)
          'main'
        else
          super
        end
      end

      def self.metadata_project_name
        'gitlab-ee'
      end
    end
  end
end
