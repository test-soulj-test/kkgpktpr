# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PublicRelease::GitalyMonthlyRelease do
  describe '#initialize' do
    it 'converts EE versions to CE versions' do
      version = ReleaseTools::Version.new('42.0.0-ee')
      release = described_class.new(version)

      expect(release.version).to eq('42.0.0')
    end
  end

  describe '#execute' do
    it 'runs the release' do
      version = ReleaseTools::Version.new('42.0.0')
      release = described_class.new(version)
      tag = double(:tag, name: 'v42.0.0')

      expect(release).to receive(:create_target_branch)
      expect(release).to receive(:compile_changelog)
      expect(release).to receive(:update_versions)

      expect(release).to receive(:create_tag).and_return(tag)

      expect(release)
        .to receive(:add_release_metadata)
        .with(tag)

      expect(release)
        .to receive(:notify_slack)
        .with(ReleaseTools::Project::Gitaly, version)

      release.execute
    end
  end

  describe '#compile_changelog' do
    it 'compiles the changelog for a stable release' do
      client = class_spy(ReleaseTools::GitlabClient)
      version = ReleaseTools::Version.new('42.0.0')
      release = described_class.new(version, client: client)
      compiler = instance_spy(ReleaseTools::ChangelogCompiler)

      expect(ReleaseTools::ChangelogCompiler)
        .to receive(:new)
        .with(release.project.canonical_or_security_path, client: client)
        .and_return(compiler)

      expect(compiler)
        .to receive(:compile)
        .with(version, branch: '42-0-stable')

      release.compile_changelog
    end

    it 'does not compile the changelog for an RC release' do
      client = class_spy(ReleaseTools::GitlabClient)
      version = ReleaseTools::Version.new('42.0.0-rc42')
      release = described_class.new(version, client: client)

      expect(ReleaseTools::ChangelogCompiler).not_to receive(:new)

      release.compile_changelog
    end
  end

  describe '#source_for_target_branch' do
    context 'when a custom commit is specified' do
      it 'returns the commit' do
        client = class_spy(ReleaseTools::GitlabClient)
        version = ReleaseTools::Version.new('42.0.0-ee')
        release = described_class.new(version, client: client, commit: 'foo')

        expect(release.source_for_target_branch).to eq('foo')
      end
    end

    context 'when no custom commit is specified' do
      it 'uses the last commit deployed to production' do
        version = ReleaseTools::Version.new('42.0.0-ee')
        release = described_class.new(version, commit: 'foo')

        allow(release).to receive(:last_production_commit).and_return('foo')

        expect(release.source_for_target_branch).to eq('foo')
      end
    end
  end
end
