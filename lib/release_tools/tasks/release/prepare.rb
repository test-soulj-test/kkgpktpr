# frozen_string_literal: true

module ReleaseTools
  module Tasks
    module Release
      class Prepare
        include ReleaseTools::Tasks::Helper

        attr_reader :version

        def initialize(version)
          @version = version
        end

        def execute
          Issue.new(version).execute

          if version.monthly?
            ReleaseTools::PickIntoLabel.create(version)
          else
            prepare_gitlab_patch_release
            prepare_omnibus_patch_release
          end
        end

        private

        def prepare_gitlab_patch_release
          merge_request = ReleaseTools::PreparationMergeRequest
                            .new(project: ReleaseTools::Project::GitlabEe, version: version.to_ee)
          merge_request.create_branch!
          create_or_show_merge_request(merge_request)
        end

        def prepare_omnibus_patch_release
          merge_request = ReleaseTools::PreparationMergeRequest
                            .new(project: ReleaseTools::Project::OmnibusGitlab, version: version.to_ce)
          merge_request.create_branch!
          create_or_show_merge_request(merge_request)
        end
      end
    end
  end
end
