# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Services::UpdateComponentService do
  let(:component) { ReleaseTools::Project::GitlabPages }
  let(:target_branch) { 'a-branch' }

  let(:internal_client) { double('ReleaseTools::GitlabClient') }
  let(:last_commit)     { 'abc123f' }
  let(:current_version) { 'A_GIT_SHA' }

  subject(:service) { described_class.new(component, target_branch) }

  before do
    allow(service).to receive(:gitlab_client).and_return(internal_client)
  end

  describe '#execute' do
    it 'updates the component version file on target branch' do
      expect(internal_client)
        .to receive(:file_contents)
        .with(described_class::TARGET_PROJECT, component.version_file, target_branch)
        .and_return(current_version)

      latest_successful_commit = double('commit', id: last_commit)
      expect(ReleaseTools::Commits)
        .to receive(:new)
        .with(component, client: internal_client)
        .and_return(double('commits', latest_successful: latest_successful_commit))

      expect(internal_client)
        .to receive(:project_path)
        .with(described_class::TARGET_PROJECT)
        .and_return('a project path')

      expect(internal_client)
        .to receive(:create_commit)
        .with(
          'a project path',
          target_branch,
          "Update #{component.project_name} to #{last_commit}",
          [
            { action: 'update', file_path: '/GITLAB_PAGES_VERSION', content: "#{last_commit}\n" }
          ]
        )

      without_dry_run do
        service.execute
      end
    end

    context 'when there are no changes' do
      it 'does not update component version' do
        expect(internal_client)
          .to receive(:file_contents)
          .with(described_class::TARGET_PROJECT, component.version_file, target_branch)
          .and_return(current_version)

        latest_successful_commit = double('commit', id: current_version)
        expect(ReleaseTools::Commits)
          .to receive(:new)
          .with(component, client: internal_client)
          .and_return(double('commits', latest_successful: latest_successful_commit))

        expect(internal_client).not_to receive(:create_commit)

        without_dry_run do
          service.execute
        end
      end
    end
  end
end
