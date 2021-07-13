# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PublicRelease::GitalyMasterRelease do
  describe '#initialize' do
    it 'converts EE versions to CE versions' do
      version = ReleaseTools::Version.new('42.0.0-rc42-ee')
      release = described_class.new(version)

      expect(release.version).to eq('42.0.0-rc42')
    end

    it 'raises when the version is not an RC version' do
      version = ReleaseTools::Version.new('42.0.0-ee')

      expect { described_class.new(version) }.to raise_error(ArgumentError)
    end
  end

  describe '#execute' do
    it 'runs the release' do
      version = ReleaseTools::Version.new('42.0.0-rc42')
      release = described_class.new(version)
      tag = double(:tag, name: 'v42.0.0-rc42')

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

  describe '#target_branch' do
    it 'returns the master branch' do
      version = ReleaseTools::Version.new('42.0.0-rc42')
      release = described_class.new(version)

      expect(release.target_branch).to eq('master')
    end
  end
end
