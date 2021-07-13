# frozen_string_literal: true

require_relative '../support/ubi_helper'

module ReleaseTools
  module Services
    class SyncRemotesService
      include ::SemanticLogger::Loggable
      include ReleaseTools::Services::SyncBranchesHelper
      include ReleaseTools::Support::UbiHelper

      def initialize(version)
        @version = version.to_ce
        @omnibus = OmnibusGitlabVersion.new(@version.to_omnibus)
        @helm    = ReleaseTools::Helm::HelmVersionFinder.new.execute(version)
      end

      def execute
        sync_stable_branches_for_projects
        sync_tags_for_projects
      end

      # Syncs stable branches for GitLab, GitLab FOSS, Omnibus GitLab,
      # CNG Image and Gitaly
      #
      # - For GitLab ee stable branches (*-*-stable-ee) are synced
      # - For GitLab FOSS, Omnibus GitLab and Gitaly, stable branches (*-*-stable) are synced
      #   Omnibus uses a single branch post 12.2
      # - For CNGImage, ee and regular stable branches are synced.
      def sync_stable_branches_for_projects
        sync_branches(Project::GitlabCe, @version.stable_branch(ee: false))
        sync_branches(Project::GitlabEe, @version.stable_branch(ee: true))
        sync_branches(Project::OmnibusGitlab, @omnibus.to_ce.stable_branch)
        sync_branches(Project::CNGImage, @version.to_ce.stable_branch)
        sync_branches(Project::Gitaly, @version.stable_branch(ee: false))
        sync_branches(Project::HelmGitlab, @helm.stable_branch)
      end

      def sync_tags_for_projects
        sync_tags(Project::GitlabCe, @version.tag(ee: false))
        sync_tags(Project::GitlabEe, @version.tag(ee: true))
        sync_tags(Project::OmnibusGitlab, @omnibus.to_ee.tag, @omnibus.to_ce.tag)
        sync_tags(Project::CNGImage, @version.to_ce.tag, @version.to_ee.tag, ubi_tag(@version.to_ee))
        sync_tags(Project::Gitaly, @version.tag(ee: false))
        sync_tags(Project::HelmGitlab, @helm.tag)
      end

      # Syncs *tags for project, it uses all project remotes: Canonical
      # Dev and Security.
      #
      # Iterates over the tags and for each of them:
      # 1. It clones from Canonical.
      # 2. Fetches the tag from Dev.
      # 3. Pushes tag to all remotes.
      #
      # Example:
      #
      # sync_tags(ReleaseTools::Project::GitLabEe, 'v13.0.0-ee')
      def sync_tags(project, *tags)
        sync_remotes = project::REMOTES.slice(:canonical, :dev, :security)
        repository = RemoteRepository.get(sync_remotes, global_depth: 50)

        tags.each do |tag|
          logger.info('Fetching tag from dev', project: project, name: tag)
          repository.fetch("refs/tags/#{tag}", remote: :dev)

          next if SharedStatus.dry_run?

          logger.info('Pushing tag to remotes', project: project, name: tag, remotes: sync_remotes.keys)
          repository.push_to_all_remotes(tag)
        end
      end
    end
  end
end
