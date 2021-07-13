# frozen_string_literal: true

module ReleaseTools
  class ComponentVersions
    include ::SemanticLogger::Loggable

    # The project that defines the component versions we're working with
    SOURCE_PROJECT = ReleaseTools::Project::GitlabEe

    FILES = [
      Project::Gitaly.version_file,
      Project::GitlabElasticsearchIndexer.version_file,
      Project::GitlabPages.version_file,
      Project::GitlabShell.version_file
    ].freeze

    def self.get_component(commit_id, file)
      ReleaseTools::GitlabClient
        .file_contents(SOURCE_PROJECT.auto_deploy_path, file, commit_id)
        .chomp
    end

    def self.for_omnibus(commit_id)
      versions = { 'VERSION' => commit_id }

      FILES.each_with_object(versions) do |file, memo|
        memo[file] = get_component(commit_id, file)
      end

      logger.info('Omnibus Versions', versions)

      versions
    end

    def self.for_cng(commit_id)
      versions = for_omnibus(commit_id)
      versions = normalize_cng_versions(versions)

      gemfile = GemfileParser.new(
        ReleaseTools::GitlabClient.file_contents(
          SOURCE_PROJECT.auto_deploy_path,
          'Gemfile.lock',
          commit_id
        )
      )

      SOURCE_PROJECT.gems.each do |gem_name, variable|
        versions[variable] = gemfile.gem_version(gem_name)
      end

      logger.info('CNG Versions', versions)

      versions
    end

    def self.normalize_cng_versions(versions)
      versions['GITLAB_VERSION'] = versions['GITLAB_ASSETS_TAG'] = versions.delete('VERSION')

      versions.each_pair do |component, version|
        # If it looks like SemVer, assume it's a tag, which we prepend with `v`
        if version.match?(/\A\d+\.\d+\.\d+(-rc\d+)?(-ee)?\z/)
          versions[component] = "v#{version}"
        end
      end

      versions
    end
  end
end
