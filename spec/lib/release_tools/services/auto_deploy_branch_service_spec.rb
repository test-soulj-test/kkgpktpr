# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Services::AutoDeployBranchService do
  let(:internal_client) { double('ReleaseTools::GitlabClient') }
  let(:internal_client_ops) { spy('ReleaseTools::GitlabOpsClient') }
  let(:branch_commit) { double(:commit, id: '1234') }

  subject(:service) { described_class.new('branch-name') }

  before do
    stub_const('ReleaseTools::GitlabClient', internal_client)
    stub_const('ReleaseTools::GitlabOpsClient', internal_client_ops)
  end

  describe '#create_branches!' do
    it 'creates auto-deploy branches' do
      branch_name = 'branch-name'

      expect(service).to receive(:latest_successful_ref)
        .and_return(branch_commit.id)
        .exactly(4)
        .times
      expect(internal_client).to receive(:find_or_create_branch).with(
        branch_name,
        branch_commit.id,
        ReleaseTools::Project::GitlabEe.auto_deploy_path
      )
      expect(internal_client).to receive(:find_or_create_branch).with(
        branch_name,
        branch_commit.id,
        ReleaseTools::Project::OmnibusGitlab.auto_deploy_path
      )
      expect(internal_client).to receive(:find_or_create_branch).with(
        branch_name,
        branch_commit.id,
        ReleaseTools::Project::CNGImage.auto_deploy_path
      )
      expect(internal_client).to receive(:find_or_create_branch).with(
        branch_name,
        branch_commit.id,
        ReleaseTools::Project::HelmGitlab.auto_deploy_path
      )

      expect(internal_client_ops).to receive(:update_variable).with(
        'gitlab-org/release/tools',
        'AUTO_DEPLOY_BRANCH',
        branch_name
      )

      without_dry_run do
        service.create_branches!
      end
    end

    it 'uses the latest commit when the auto_deploy_tag_latest feature flag is enabled' do
      branch_name = 'branch-name'
      commits_spy = instance_spy(ReleaseTools::Commits)
      commit = double(:commit, id: '123')

      enable_feature(:auto_deploy_tag_latest)

      allow(ReleaseTools::Commits)
        .to receive(:new)
        .and_return(commits_spy)

      expect(commits_spy).to receive(:latest)
        .and_return(commit)
        .exactly(4)
        .times

      expect(internal_client).to receive(:find_or_create_branch).with(
        branch_name,
        commit.id,
        ReleaseTools::Project::GitlabEe.auto_deploy_path
      )

      expect(internal_client).to receive(:find_or_create_branch).with(
        branch_name,
        commit.id,
        ReleaseTools::Project::OmnibusGitlab.auto_deploy_path
      )

      expect(internal_client).to receive(:find_or_create_branch).with(
        branch_name,
        commit.id,
        ReleaseTools::Project::CNGImage.auto_deploy_path
      )

      expect(internal_client).to receive(:find_or_create_branch).with(
        branch_name,
        commit.id,
        ReleaseTools::Project::HelmGitlab.auto_deploy_path
      )

      expect(internal_client_ops).to receive(:update_variable).with(
        'gitlab-org/release/tools',
        'AUTO_DEPLOY_BRANCH',
        branch_name
      )

      without_dry_run do
        service.create_branches!
      end
    end

    it 'raises when no latest commit is found' do
      commits_spy = instance_spy(ReleaseTools::Commits)
      commit_spy = instance_spy(ReleaseTools::AutoDeploy::MinimumCommit)

      allow(ReleaseTools::Commits).to receive(:new).and_return(commits_spy)
      allow(ReleaseTools::AutoDeploy::MinimumCommit)
        .to receive(:new)
        .and_return(commit_spy)

      allow(commits_spy).to receive(:latest_successful_on_build).and_return(nil)
      allow(commit_spy).to receive(:sha).and_return(nil)

      expect do
        without_dry_run { service.create_branches! }
      end.to raise_error(RuntimeError)
    end
  end
end
