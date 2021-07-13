# frozen_string_literal: true

module ReleaseTools
  module Qa
    SPECIAL_TEAM_LABELS = [
      'Community contribution'
    ].freeze

    PROJECTS = [
      ReleaseTools::Project::GitlabEe,
      ReleaseTools::Project::Gitaly,
      ReleaseTools::Project::GitlabPages,
      ReleaseTools::Project::GitlabShell
    ].freeze

    def self.group_labels
      @group_labels ||= SPECIAL_TEAM_LABELS + GitlabClient.group_labels('gitlab-org', search: 'group::', per_page: 100)
        .auto_paginate
        .select { |l| l.name.start_with?('group::') }
        .collect(&:name)
    end
  end
end
