# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PassingBuild do
  let(:fake_commit) { double('Commit', id: SecureRandom.hex(20)) }
  let(:target_branch) { '11-10-auto-deploy-1234' }

  subject(:service) { described_class.new(target_branch) }

  describe '#execute' do
    let(:fake_commits) { spy }

    before do
      stub_const('ReleaseTools::Commits', fake_commits)
    end

    it 'raises an error without a dev commit' do
      commit_spy = instance_spy(ReleaseTools::AutoDeploy::MinimumCommit)

      allow(ReleaseTools::AutoDeploy::MinimumCommit)
        .to receive(:new)
        .with(ReleaseTools::Project::GitlabEe, target_branch)
        .and_return(commit_spy)

      expect(commit_spy).to receive(:sha).and_return('foo')

      expect(fake_commits).to receive(:latest_successful_on_build)
        .with(limit: 'foo')
        .and_return(nil)

      expect { service.execute }
        .to raise_error(/Unable to find a passing/)
    end

    it 'returns the latest successful commit on Build' do
      commit_spy = instance_spy(ReleaseTools::AutoDeploy::MinimumCommit)

      allow(ReleaseTools::AutoDeploy::MinimumCommit)
        .to receive(:new)
        .with(ReleaseTools::Project::GitlabEe, target_branch)
        .and_return(commit_spy)

      expect(commit_spy).to receive(:sha).and_return('foo')

      expect(fake_commits)
        .to receive(:latest_successful_on_build)
        .with(limit: 'foo')
        .and_return(fake_commit)

      expect(service.execute).to eq(fake_commit)
    end

    it 'returns the latest commit when auto_deploy_tag_latest is enabled' do
      enable_feature(:auto_deploy_tag_latest)

      expect(fake_commits).to receive(:latest)
        .and_return(fake_commit)

      expect(service.execute).to eq(fake_commit)
    end
  end
end
