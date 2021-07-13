# frozen_string_literal: true

module ReleaseTools
  class ReleaseMetadataUploader
    include ::SemanticLogger::Loggable

    # The project on ops.gitlab.net to store the release metadata in.
    PROJECT = Project::Release::Metadata

    def upload(name, data)
      return if data.empty?
      return if SharedStatus.dry_run?

      json = JSON.pretty_generate(format_release_metadata(data))
      message = "Add release data for #{name}"
      path = file_path_for(name)

      logger.info('Uploading metadata', version: name)

      begin
        GitlabOpsClient.create_file(PROJECT, path, PROJECT.default_branch, json, message)
      rescue Gitlab::Error::BadRequest
        # If a CI job running this code fails later on and is retried, the JSON
        # file may already exist. Instead of erroring out again, we update the
        # existing file. If that also fails, manual intervention is likely
        # needed anyway; so we don't handle that case explicitly.
        GitlabOpsClient.edit_file(PROJECT, path, PROJECT.default_branch, json, message)
      end
    end

    private

    def file_path_for(name)
      prefix = name.split('.').first

      # To reduce the number of files per directory, we create a new directory
      # for every major version. Even at 4 entries per day, this translates to
      # only 1460 files per directory.
      "releases/#{prefix}/#{name}.json"
    end

    def format_release_metadata(data)
      {
        security: SharedStatus.security_release?,
        releases: data.releases.each_with_object({}) do |(_, obj), hash|
          hash[obj.name.to_sym] = {
            version: obj.version,
            sha: obj.sha,
            ref: obj.ref,
            tag: obj.tag?
          }
        end
      }
    end
  end
end
