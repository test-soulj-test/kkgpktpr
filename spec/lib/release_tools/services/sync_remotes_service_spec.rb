# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Services::SyncRemotesService do
  let(:version) { ReleaseTools::Version.new('1.2.3') }

  before do
    helm_finder = instance_double(ReleaseTools::Helm::HelmVersionFinder, execute: ReleaseTools::Version.new('3.2.1'))
    allow(ReleaseTools::Helm::HelmVersionFinder).to receive(:new).and_return(helm_finder)
  end

  describe '#execute' do
    it 'syncs stable branches for the version' do
      service = described_class.new(version)

      allow(service).to receive(:sync_tags).and_return(true)

      expect(service).to receive(:sync_branches)
        .with(ReleaseTools::Project::GitlabCe, '1-2-stable')
      expect(service).to receive(:sync_branches)
        .with(ReleaseTools::Project::GitlabEe, '1-2-stable-ee')
      expect(service).to receive(:sync_branches)
        .with(ReleaseTools::Project::OmnibusGitlab, '1-2-stable')
      expect(service).to receive(:sync_branches)
        .with(ReleaseTools::Project::CNGImage, '1-2-stable')
      expect(service).to receive(:sync_branches)
        .with(ReleaseTools::Project::Gitaly, '1-2-stable')
      expect(service).to receive(:sync_branches)
        .with(ReleaseTools::Project::HelmGitlab, '3-2-stable')

      service.execute
    end

    it 'syncs tags for the version' do
      service = described_class.new(version)

      allow(service).to receive(:sync_branches).and_return(true)

      expect(service).to receive(:sync_tags)
        .with(ReleaseTools::Project::GitlabCe, 'v1.2.3')
      expect(service).to receive(:sync_tags)
        .with(ReleaseTools::Project::GitlabEe, 'v1.2.3-ee')
      expect(service).to receive(:sync_tags)
        .with(ReleaseTools::Project::OmnibusGitlab, '1.2.3+ee.0', '1.2.3+ce.0')
      expect(service).to receive(:sync_tags)
        .with(ReleaseTools::Project::CNGImage, 'v1.2.3', 'v1.2.3-ee', 'v1.2.3-ubi8')
      expect(service).to receive(:sync_tags)
        .with(ReleaseTools::Project::Gitaly, 'v1.2.3')
      expect(service).to receive(:sync_tags)
        .with(ReleaseTools::Project::HelmGitlab, 'v3.2.1')

      service.execute
    end
  end

  describe '#sync_branches' do
    let(:fake_repo) { instance_double(ReleaseTools::RemoteRepository).as_null_object }
    let(:project) { ReleaseTools::Project::GitlabEe }

    context 'with invalid remotes' do
      it 'logs an error and returns' do
        stub_const("ReleaseTools::Project::GitlabEe::REMOTES", {})

        service = described_class.new(version)

        expect(ReleaseTools::RemoteRepository).not_to receive(:get)

        service.sync_branches(project, 'branch')
      end
    end

    context 'with a successful merge' do
      it 'merges branch and pushes' do
        branch = '1-2-stable-ee'

        successful_merge = double(status: double(success?: true))

        expect(ReleaseTools::RemoteRepository).to receive(:get)
          .with(
            a_hash_including(project::REMOTES),
            a_hash_including(branch: branch)
          ).and_return(fake_repo)

        expect(fake_repo).to receive(:merge)
          .with("dev/#{branch}", no_ff: true)
          .and_return(successful_merge)

        expect(fake_repo).to receive(:push_to_all_remotes).with(branch)

        without_dry_run do
          described_class.new(version).sync_branches(project, branch)
        end
      end
    end

    context 'with a failed merge' do
      it 'logs a fatal message with the output' do
        branch = '1-2-stable-ee'

        failed_merge = double(status: double(success?: false), output: 'output')

        allow(ReleaseTools::RemoteRepository).to receive(:get).and_return(fake_repo)

        expect(fake_repo).to receive(:merge).and_return(failed_merge)
        expect(fake_repo).not_to receive(:push_to_all_remotes)

        service = described_class.new(version)
        expect(service.logger).to receive(:fatal)
          .with(anything, a_hash_including(output: 'output'))

        without_dry_run do
          service.sync_branches(project, branch)
        end
      end
    end
  end

  describe '#sync_tags' do
    let(:fake_repo) { instance_double(ReleaseTools::RemoteRepository).as_null_object }
    let(:project) { ReleaseTools::Project::GitlabEe }
    let(:tag) { 'v1.2.3' }

    it 'fetches tags and pushes' do
      allow(ReleaseTools::RemoteRepository).to receive(:get).and_return(fake_repo)

      expect(fake_repo).to receive(:fetch).with("refs/tags/#{tag}", remote: :dev)
      expect(fake_repo).to receive(:push_to_all_remotes).with(tag)

      expect(ReleaseTools::RemoteRepository).to receive(:get)
        .with(
          a_hash_including(project::REMOTES),
          a_hash_including(global_depth: 50)
        ).and_return(fake_repo)

      without_dry_run do
        described_class.new(version).sync_tags(project, tag)
      end
    end
  end
end
