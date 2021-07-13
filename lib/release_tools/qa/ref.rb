# frozen_string_literal: true

module ReleaseTools
  module Qa
    class Ref
      TAG_REGEX = /(?<prefix>v?)(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(-rc?(?<rc>\d+))?/.freeze
      STABLE_BRANCH_REGEX = /^(?<major>\d+)-(?<minor>\d+)-(?<stable>stable)$/.freeze

      AUTO_DEPLOY_TAG_REGEX = /
        \A
        (?<prefix>\w?)
        (?<major>\d+)
        \.
        (?<minor>\d+)
        \.
        (?<patch>\d+)
        -
        (?<commit>\h{11,})
        \.
        (?<omnibus_commit>\h{11,})
        \z
      /x.freeze

      def initialize(ref)
        @ref = ref
      end

      def ref
        matches = @ref.match(AUTO_DEPLOY_TAG_REGEX)

        if matches && matches[:commit]
          matches[:commit]
        else
          @ref
        end
      end

      def for_project(project)
        given_ref = ref.dup
        given_ref.concat('-ee') if include_suffix?

        if project.respond_to?(:version_file)
          component_ref(project, given_ref)
        else
          given_ref
        end
      end

      private

      def include_suffix?
        tag? || stable_branch?
      end

      def tag?
        ref.match?(TAG_REGEX) && !ref.match?(AUTO_DEPLOY_TAG_REGEX)
      end

      def stable_branch?
        ref.match?(STABLE_BRANCH_REGEX)
      end

      def component_ref(project, given_ref)
        # When given a component project, we need its version in GitLab EE
        component_ref = Retriable.with_context(:api) do
          GitlabClient.file_contents(
            Project::GitlabEe.security_path,
            project.version_file,
            given_ref
          ).chomp
        end

        # This check should be removed as part of
        # https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1628.
        if project == Project::GitlabWorkhorse && component_ref == 'VERSION'
          component_ref = Retriable.with_context(:api) do
            GitlabClient.file_contents(
              Project::GitlabEe.security_path,
              'VERSION',
              given_ref
            ).chomp
          end
        end

        tag = component_ref.match(TAG_REGEX)

        if tag.nil? || tag[:prefix].present?
          # For no match or a tag already including a prefix, return as-is
          component_ref
        else
          "v#{component_ref}"
        end
      end
    end
  end
end
