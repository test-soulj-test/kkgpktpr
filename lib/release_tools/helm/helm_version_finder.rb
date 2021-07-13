# frozen_string_literal: true

module ReleaseTools
  module Helm
    # Determining of the Helm charts version based on a GitLab version.
    class HelmVersionFinder
      # The regex to use for extracting GitLab versions from tag messages.
      TAG_REGEX = /contains GitLab (?:CE|EE) (?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)/.freeze

      def initialize(client = GitlabClient)
        @client = client
      end

      # Returns the next Helm version to use for the given GitLab version.
      def execute(version)
        tags = release_tags
        exact = matching_tags(tags, version.major, version.minor, version.patch)

        # If there already is a Helm version for the input version. we just
        # return that one.
        return latest_version(exact) if exact.any?

        # Next, we try to find Helm tags for the GitLab MAJOR.MINOR version. If
        # found, we will return a new patch version based on the found version.
        minor = matching_tags(tags, version.major, version.minor)

        return Version.new(latest_version(minor).next_patch) if minor.any?

        # Next, we try to find Helm tags for the GitLab MAJOR version. If found,
        # we will return a new minor version based on the found version.
        major = matching_tags(tags, version.major)

        return Version.new(latest_version(major).next_minor) if major.any?

        # No tags were found for the specified GitLab version. In this case we
        # simply take the latest Helm version, and generate a new major version
        # based on that.
        return Version.new(latest_version(tags.keys).next_major) if tags.any?

        # If there are no tags at all, which in practise is not the case, we
        # just raise an error.
        raise 'The Helm charts project does not have any Git tags'
      end

      def matching_tags(tags, major, minor = nil, patch = nil)
        found = []

        tags.each do |tag, (tmajor, tminor, tpatch)|
          matches = major == tmajor
          matches &&= minor == tminor if minor
          matches &&= patch == tpatch if patch

          found.push(tag) if matches
        end

        found
      end

      def release_tags
        tags = {}

        @client
          .tags(Project::HelmGitlab, search: '^v', per_page: 100)
          .auto_paginate do |tag|
            matches = tag.message.match(TAG_REGEX)

            # This is just an extra check to make sure we don't process tags
            # called for example "vroom vroom".
            next unless matches

            tags[tag.name] = [
              matches[:major].to_i,
              matches[:minor].to_i,
              matches[:patch].to_i
            ]
          end

        tags
      end

      def latest_version(versions)
        max = VersionSorter.sort(versions).last # rubocop:disable Style/RedundantSort

        Version.new(max.sub('v', ''))
      end
    end
  end
end
