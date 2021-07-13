# frozen_string_literal: true

module ReleaseTools
  class GitlabOpsClient < GitlabClient
    OPS_API_ENDPOINT = 'https://ops.gitlab.net/api/v4'

    def self.client
      @client ||= Gitlab.client(
        endpoint: OPS_API_ENDPOINT,
        private_token: ENV['RELEASE_BOT_OPS_TOKEN'],
        httparty: httparty_opts
      )
    end

    def self.project_path(project)
      if project.respond_to?(:ops_path)
        project.ops_path
      else
        project
      end
    end

    # Downloads release metadata for the given version.
    #
    # The `version` argument must be an instance of `ReleaseTools::Version`.
    def self.release_metadata(version)
      file = "releases/#{version.major}/#{version.to_normalized_version}.json"
      json = Retriable.with_context(:api) do
        GitlabOpsClient.file_contents(ReleaseMetadataUploader::PROJECT, file)
      rescue Gitlab::Error::NotFound
        return {}
      end

      JSON.parse(json)
    end
  end
end
