# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::AutoDeploy::Cleanup do
  let(:cleanup) { described_class.new }

  shared_examples 'cleaning up auto-deploy branches' do
    it 'cleans up outdated auto-deploy branches' do
      allow(cleanup).to receive(:cleanup_project_branches)

      cleanup.cleanup

      expect(cleanup)
        .to have_received(:cleanup_project_branches)
        .with(project.path, ReleaseTools::GitlabClient)

      expect(cleanup)
        .to have_received(:cleanup_project_branches)
        .with(project.security_path, ReleaseTools::GitlabClient)

      expect(cleanup)
        .to have_received(:cleanup_project_branches)
        .with(project.dev_path, ReleaseTools::GitlabDevClient)
    end
  end

  describe '#cleanup' do
    context 'for GitLab EE' do
      let(:project) { ReleaseTools::Project::GitlabEe }

      include_examples 'cleaning up auto-deploy branches'
    end

    context 'for Omnibus' do
      let(:project) { ReleaseTools::Project::OmnibusGitlab }

      include_examples 'cleaning up auto-deploy branches'
    end

    context 'for CNG' do
      let(:project) { ReleaseTools::Project::CNGImage }

      include_examples 'cleaning up auto-deploy branches'
    end

    context 'for Helm' do
      let(:project) { ReleaseTools::Project::HelmGitlab }

      include_examples 'cleaning up auto-deploy branches'
    end
  end

  describe '#cleanup_project_branches' do
    context 'when there are regular branches' do
      it 'does not delete them' do
        client = class_spy(ReleaseTools::GitlabClient)
        branch = double(:branch, name: 'foo')

        allow(client)
          .to receive(:branches)
          .with('foo', search: '-auto-deploy-')
          .and_return(Gitlab::PaginatedResponse.new([branch]))

        expect(client).not_to receive(:delete_branch)

        cleanup.cleanup_project_branches('foo', client)
      end
    end

    context 'when there are auto-deploy branches with invalid dates' do
      it 'does not delete them' do
        client = class_spy(ReleaseTools::GitlabClient)
        branch = double(:branch, name: '13-2-auto-deploy-00009999')

        allow(client)
          .to receive(:branches)
          .with('foo', search: '-auto-deploy-')
          .and_return(Gitlab::PaginatedResponse.new([branch]))

        expect(client).not_to receive(:delete_branch)

        cleanup.cleanup_project_branches('foo', client)
      end
    end

    context 'when there are recent auto-deploy branches' do
      it 'does not delete them' do
        client = class_spy(ReleaseTools::GitlabClient)
        time = Date.today.strftime('%Y%m%d')
        branch = double(:branch, name: "13-2-auto-deploy-#{time}")

        allow(client)
          .to receive(:branches)
          .with('foo', search: '-auto-deploy-')
          .and_return(Gitlab::PaginatedResponse.new([branch]))

        expect(client).not_to receive(:delete_branch)

        cleanup.cleanup_project_branches('foo', client)
      end
    end

    context 'when the same auto-deploy branch is returned by the API multiple times' do
      it 'only deletes the branch once' do
        client = class_spy(ReleaseTools::GitlabClient)
        branch = double(:branch, name: '13-2-auto-deploy-19990101')

        allow(client)
          .to receive(:branches)
          .with('foo', search: '-auto-deploy-')
          .and_return(Gitlab::PaginatedResponse.new([branch, branch]))

        expect(client).to receive(:delete_branch).with(branch.name, 'foo').once

        cleanup.cleanup_project_branches('foo', client)
      end
    end

    context 'when there are auto-deploy branches to delete' do
      it 'deletes them' do
        client = class_spy(ReleaseTools::GitlabClient)
        branch = double(:branch, name: '13-2-auto-deploy-19990101')

        allow(client)
          .to receive(:branches)
          .with('foo', search: '-auto-deploy-')
          .and_return(Gitlab::PaginatedResponse.new([branch]))

        expect(client).to receive(:delete_branch).with(branch.name, 'foo')

        cleanup.cleanup_project_branches('foo', client)
      end
    end
  end

  describe '#auto_deploy_branch_date' do
    context 'for a valid auto-deploy branch name' do
      it 'returns the date of the branch' do
        expect(cleanup.auto_deploy_branch_date('13-2-auto-deploy-1999010112'))
          .to eq(Time.new(1999, 1, 1, 12))
      end

      it 'supports branch names without the hour' do
        expect(cleanup.auto_deploy_branch_date('13-2-auto-deploy-19990101'))
          .to eq(Time.new(1999, 1, 1))
      end
    end

    context 'for an invalid auto-deploy branch name' do
      it 'raises ArgumentError' do
        expect { cleanup.auto_deploy_branch_date('13-2-auto-deploy-00009999') }
          .to raise_error(ArgumentError)
      end
    end
  end
end
