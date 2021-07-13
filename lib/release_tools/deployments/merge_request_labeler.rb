# frozen_string_literal: true

module ReleaseTools
  module Deployments
    # Adding of environment labels to deployed merge requests.
    class MergeRequestLabeler
      include ::SemanticLogger::Loggable

      # The labels to apply to a merge request when it is deployed.
      #
      # The keys are the environments deployed to, the values the label to
      # apply.
      DEPLOYMENT_LABELS = {
        'gstg' => 'workflow::staging',
        'gprd-cny' => 'workflow::canary',
        'gprd' => 'workflow::production',
        'pre' => 'released::candidate',
        'release' => 'released::published'
      }.freeze

      # environment - The name of the environment that was deployed to.
      # deployments - An Array of `DeploymentTrackes::Deployment` instances,
      #               containing data about a deployment.
      def label_merge_requests(environment, deployments)
        label = DEPLOYMENT_LABELS[environment]

        unless label
          logger.warn(
            'Not updating merge requests as there is no label for this environment',
            environment: environment
          )

          return
        end

        logger.info(
          'Adding label to deployed merge requests',
          environment: environment,
          label: label
        )

        MergeRequestUpdater
          .for_successful_deployments(deployments)
          .add_label(label)
      end
    end
  end
end
