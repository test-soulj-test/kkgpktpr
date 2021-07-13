# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PublicRelease::GitalyRelease do
  let(:release) do
    Class.new do
      include ReleaseTools::PublicRelease::Release
      include ReleaseTools::PublicRelease::GitalyRelease

      attr_reader :version, :client, :release_metadata

      def initialize
        @version = ReleaseTools::Version.new('42.0.0-rc42')
        @client = ReleaseTools::GitlabClient
        @release_metadata = ReleaseTools::ReleaseMetadata.new
      end

      def target_branch
        'master'
      end
    end.new
  end

  describe '#update_versions' do
    it 'updates the version files' do
      expect(release)
        .to receive(:commit_version_files)
        .with(
          'master',
          {
            'VERSION' => '42.0.0-rc42',
            'ruby/proto/gitaly/version.rb' => a_string_including("VERSION = '42.0.0-rc42'")
          },
          skip_ci: true
        )

      release.update_versions
    end
  end

  describe '#create_tag' do
    it 'creates the Git tag' do
      expect(release.client)
        .to receive(:find_or_create_tag)
        .with(
          release.project_path,
          'v42.0.0-rc42',
          'master',
          message: 'Version v42.0.0-rc42'
        )

      release.create_tag
    end
  end

  describe '#add_release_metadata' do
    it 'adds the Gitaly release metadata' do
      tag =
        double(:tag, name: 'v42.0.0-rc42', commit: double(:commit, id: '123'))

      expect(release.release_metadata)
        .to receive(:add_release)
        .with(
          name: 'gitaly',
          version: '42.0.0-rc42',
          sha: '123',
          ref: 'v42.0.0-rc42',
          tag: true
        )

      release.add_release_metadata(tag)
    end
  end

  describe '#project' do
    it 'returns the project to use for releases' do
      expect(release.project).to eq(ReleaseTools::Project::Gitaly)
    end
  end
end
