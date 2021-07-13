# frozen_string_literal: true

require 'spec_helper'
require 'release_tools/tasks'

describe ReleaseTools::Tasks::AutoDeploy::Prepare do
  let(:active_version) { ReleaseTools::Version.new('13.1') }
  let(:now) { Time.local(2020, 2, 22, 16) }
  let(:auto_deploy_branch) { '13-1-auto-deploy-2020022216' }

  subject(:prepare) { described_class.new }

  before do
    schedule =
      instance_double(ReleaseTools::ReleaseManagers::Schedule,
                      active_version: active_version)
    allow(ReleaseTools::ReleaseManagers::Schedule).to receive(:new).and_return(schedule)
  end

  around do |example|
    Timecop.freeze(now, &example)
  end

  describe '#execute' do
    it 'prepares the monthly release, create branches, and notify results' do
      expect(prepare).to receive(:check_version)
      expect(prepare).to receive(:prepare_monthly_release)

      results = double('results')
      expect(prepare).to receive(:create_branches).and_return(results)

      expect(prepare).to receive(:notify_results).with(results)

      prepare.execute
    end

    context 'when the active version cannot be retrieved' do
      let(:active_version) { nil }

      it 'performs no action' do
        expect(prepare).not_to receive(:prepare_monthly_release)
        expect(prepare).not_to receive(:create_branches)
        expect(prepare).not_to receive(:notify_results)

        expect do
          prepare.execute
        end.to raise_error('Cannot detect the active version')
      end
    end
  end

  describe '#prepare_monthly_release' do
    it 'prepares for the monthly release' do
      task = double('Release::Prepare')
      expect(ReleaseTools::Tasks::Release::Prepare).to receive(:new)
        .with(active_version)
        .and_return(task)

      expect(task).to receive(:execute)

      prepare.prepare_monthly_release
    end
  end

  describe '#create_branches' do
    it 'creates the auto_deploy branch' do
      service = double('AutoDeployBranchService')
      expect(ReleaseTools::Services::AutoDeployBranchService).to receive(:new)
        .with(auto_deploy_branch)
        .and_return(service)

      expect(service).to receive(:create_branches!)

      prepare.create_branches
    end
  end

  describe '#notify_results' do
    it 'notify branch_creation on slack' do
      results = double('results')

      expect(ReleaseTools::Slack::AutoDeployNotification).to receive(:on_create)
        .with(results)

      prepare.notify_results(results)
    end
  end

  describe '#check_version' do
    it 'does not fail' do
      expect { prepare.check_version }.not_to raise_error
    end

    context 'when the active version cannot be retrieved' do
      let(:active_version) { nil }

      it 'raises an error' do
        expect do
          prepare.check_version
        end.to raise_error('Cannot detect the active version')
      end
    end
  end
end
