# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Security::SyncRemotesService do
  describe '#execute' do
    it 'syncs master branch for every project' do
      service = described_class.new

      expect(service).to receive(:sync_branches)
        .with(ReleaseTools::Project::GitlabEe, 'master')

      expect(service).to receive(:sync_branches)
        .with(ReleaseTools::Project::GitlabCe, 'master')

      expect(service).to receive(:sync_branches)
        .with(ReleaseTools::Project::OmnibusGitlab, 'master')

      expect(service).to receive(:sync_branches)
        .with(ReleaseTools::Project::Gitaly, 'master')

      expect(service).to receive(:sync_branches)
        .with(ReleaseTools::Project::HelmGitlab, 'master')

      service.execute
    end
  end
end
