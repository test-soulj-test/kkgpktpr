# frozen_string_literal: true

module ReleaseTools
  module Helm
    # Determining of GitLab versions for a given Helm version.
    #
    # When releasing a version of Helm, the GitLab version may not be specified.
    # In such a case we will try to obtain the GitLab version from the
    # appVersion field of the top-level Chart.yaml file.
    #
    # When releasing a new major/minor version of Helm, the appVersion field
    # will be set to the project's default branch. The API release code for Helm
    # (PublicRelease::HelmGitlabRelease) expects a Version object to be passed
    # as the GitLab version, and these don't support branch names as input.
    # Thus, when we find such a version below we produce an error; requiring the
    # user to explicitly specify the GitLab version to use.
    #
    # This should not pose any problems. When releasing a new version of GitLab,
    # we provide the GitLab version already. Tagging a Helm version while using
    # a default branch for the appVersion fields is something that doesn't
    # happen either. Thus, the checks/errors are more of a precaution to prevent
    # users from performing an incorrect release.
    class GitlabVersionFinder
      # The name of the file containing the top-level Chart information.
      CHART_FILE = 'Chart.yaml'

      def initialize(client = GitlabClient)
        @client = client
      end

      def execute(helm_version)
        project = Project::HelmGitlab
        path = project.canonical_or_security_path
        data = Retriable.with_context(:api) do
          @client.file_contents(path, CHART_FILE, helm_version.stable_branch)
        rescue Gitlab::Error::NotFound
          @client.file_contents(path, CHART_FILE, project.default_branch)
        end

        chart_data = YAML.safe_load(data)
        app_version = Version.new(chart_data['appVersion'])

        unless app_version.valid?
          raise "The version #{app_version.inspect} is not a valid GitLab " \
            "version for the Helm version #{helm_version}"
        end

        app_version
      end
    end
  end
end
