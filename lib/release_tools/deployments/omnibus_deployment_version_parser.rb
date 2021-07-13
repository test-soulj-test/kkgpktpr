# frozen_string_literal: true

module ReleaseTools
  module Deployments
    # Class for parsing deployment versions into an Omnibus SHA and ref.
    class OmnibusDeploymentVersionParser
      # The default ref/branch to use when none can be found for a deployed SHA.
      DEFAULT_REF = Project::OmnibusGitlab.default_branch

      DeploymentVersion = Struct.new(:sha, :ref, :tag) do
        alias_method :tag?, :tag
      end

      # Parses the supplied version into a `DeploymentVersion`, which contains:
      #
      # * The deployed SHA
      # * The deployed branch or tag name
      # * A boolean indicating if a tag was deployed instead of a branch
      #
      # This method will raise an ArgumentError if the version could not be
      # parsed.
      def parse(version)
        if (parsed = deployment_from_version(version))
          return parsed
        end

        if (parsed = deployment_from_tag(version))
          return parsed
        end

        raise(ArgumentError, "Failed to extract deploy details from #{version}")
      end

      private

      def deployment_from_version(version)
        matches = version.match(Qa::Ref::AUTO_DEPLOY_TAG_REGEX)

        return unless matches && matches[:omnibus_commit]

        sha = fetch_complete_sha(matches[:omnibus_commit])
        meta = GitlabOpsClient.release_metadata(Version.new(version))
        ref = meta.dig('releases', 'omnibus-gitlab-ee', 'ref') || DEFAULT_REF

        DeploymentVersion.new(sha, ref, false)
      end

      def deployment_from_tag(version)
        return unless version.match?(DeploymentVersionParser::TAG_REGEX)

        tag_name = Version.new(version).to_omnibus(ee: true)
        tag = GitlabClient
          .tag(Project::OmnibusGitlab.canonical_or_security_path, tag: tag_name)

        DeploymentVersion.new(tag.commit.id, tag.name, true)
      rescue Gitlab::Error::Error
        nil
      end

      def fetch_complete_sha(short_sha)
        GitlabClient
          .commit(Project::OmnibusGitlab.canonical_or_security_path, ref: short_sha)
          .id
      end
    end
  end
end
