# frozen_string_literal: true

namespace :auto_deploy do
  desc "Prepare for auto-deploy by creating branches from the latest green commit on gitlab and omnibus-gitlab"
  task :prepare do
    ReleaseTools::Tasks::AutoDeploy::Prepare.new.execute
  end

  desc 'Pick commits into the auto deploy branches'
  task :pick do
    pick = lambda do |project, branch_name|
      ReleaseTools.logger.info(
        'Picking into auto-deploy branch',
        project: project.auto_deploy_path,
        target: branch_name
      )

      ReleaseTools::CherryPick::AutoDeployService
        .new(project, branch_name)
        .execute
    end

    branch_name = ReleaseTools::AutoDeployBranch.current_name

    pick[ReleaseTools::Project::GitlabEe, branch_name]
    pick[ReleaseTools::Project::OmnibusGitlab, branch_name]
    pick[ReleaseTools::Project::CNGImage, branch_name]
    pick[ReleaseTools::Project::HelmGitlab, branch_name]
  end

  desc "Tag the auto-deploy branches from the latest passing builds"
  task :tag do
    ReleaseTools::Tasks::AutoDeploy::Tag.new.execute
  end

  desc "Validate production pre-checks"
  task :check_production do
    ReleaseTools::Tasks::AutoDeploy::CheckProduction.new.execute
  end

  desc "Perform Canary promotion pre-checks after a baking period"
  task :baking_time do
    ReleaseTools::Tasks::AutoDeploy::BakingTime.new.execute
  end

  desc 'Cleans up old auto-deploy branches'
  task :cleanup do
    ReleaseTools::AutoDeploy::Cleanup.new.cleanup
  end

  desc 'Triggers a Deployer pipeline to a specific environment (DEPLOY_ENVIRONMENT) using a deployer branch (TRIGGER_REF)'
  task :deploy do
    ReleaseTools::Tasks::AutoDeploy::DeployTrigger
      .new(environment: ENV['DEPLOY_ENVIRONMENT'], ref: ENV['TRIGGER_REF'])
      .execute
  end

  namespace :wait do
    desc 'Wait for a tagged Omnibus pipeline to complete'
    task :omnibus do
      waiter = ReleaseTools::AutoDeploy::WaitForPackage.new(
        ReleaseTools::Project::OmnibusGitlab, 'omnibus-gitlab-ee'
      )

      if waiter.execute
        ReleaseTools.logger.info('Omnibus package built successfully')
      else
        exit 1
      end
    end

    desc 'Wait for a tagged Helm pipeline to complete'
    task :helm do
      # NOTE: Wait on a Helm pipeline but use the CNG metadata entry
      #
      # Due to the way Helm is tagged, it doesn't currently get a metadata
      # entry. However, it gets the exact same tag as the CNG image, so we use
      # that entry instead.
      waiter = ReleaseTools::AutoDeploy::WaitForPackage.new(
        ReleaseTools::Project::HelmGitlab, 'cng-ee'
      )

      if waiter.execute
        ReleaseTools.logger.info('Helm package built successfully')
      else
        exit 1
      end
    end

    desc 'Wait for a deployment to complete. The pipeline is identified by DEPLOY_PIPELINE_ID variable'
    task :deployment do
      client = ReleaseTools::GitlabOpsClient

      waiter = ReleaseTools::AutoDeploy::WaitForPipeline.new(
        client, ReleaseTools::Project::Deployer, ENV['DEPLOY_PIPELINE_ID']
      )

      if waiter.execute
        ReleaseTools.logger.info('Deployment finished successfully')
      else
        exit 1
      end
    end
  end

  namespace :metrics do
    desc 'Tracks deployment start time'
    task :start_time do
      ReleaseTools::Metrics::CoordinatedDeployment::TrackStartTime.new
        .execute
    end

    desc 'Tracks deployment duration and number of deployments'
    task :end_time do
      ReleaseTools::Metrics::CoordinatedDeployment::Duration.new(
        deploy_version: ENV['DEPLOY_VERSION'],
        start_time: ENV['DEPLOY_START_TIME']
      ).execute
    end
  end
end
