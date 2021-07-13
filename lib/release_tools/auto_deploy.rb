# frozen_string_literal: true

require 'release_tools/auto_deploy/naming'
require 'release_tools/auto_deploy/builder/cng_image'
require 'release_tools/auto_deploy/builder/omnibus'
require 'release_tools/auto_deploy/pipeline'
require 'release_tools/auto_deploy/tag'
require 'release_tools/auto_deploy/tagger/release_metadata_tracking'
require 'release_tools/auto_deploy/tagger/cng_image'
require 'release_tools/auto_deploy/tagger/coordinator'
require 'release_tools/auto_deploy/tagger/helm'
require 'release_tools/auto_deploy/tagger/omnibus'
require 'release_tools/auto_deploy/version'
require 'release_tools/auto_deploy/wait_for_package'
require 'release_tools/auto_deploy/wait_for_pipeline'
require 'release_tools/auto_deploy/cleanup'
require 'release_tools/auto_deploy/minimum_commit'

# TODO: Relocate -- https://gitlab.com/gitlab-org/release-tools/-/issues/491
require 'release_tools/auto_deploy_branch'

module ReleaseTools
  module AutoDeploy
    module_function

    # Determines if auto-deploys are happening in "coordinated" mode
    #
    # See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1353
    def coordinator_pipeline?
      if Feature.enabled?(:auto_deploy_coordinator)
        # With the feature flag enabled, require a tagged pipeline
        ENV['CI_COMMIT_TAG'].present? || ENV['AUTO_DEPLOY_TAG'].present?
      else
        # With the feature flag disabled, fall back to previous behavior
        true
      end
    end
  end
end
