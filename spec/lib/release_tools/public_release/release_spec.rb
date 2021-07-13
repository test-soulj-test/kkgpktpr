# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PublicRelease::Release do
  let(:client) { class_spy(ReleaseTools::GitlabClient) }
  let(:version) { ReleaseTools::Version.new('1.2.3') }

  let(:release) do
    klass = Class.new do
      include ReleaseTools::PublicRelease::Release

      attr_reader :version, :client, :release_metadata

      def initialize(
        version,
        client: ReleaseTools::GitlabClient,
        release_metadata: ReleaseTools::ReleaseMetadata.new
      )
        @version = version
        @client = client
        @release_metadata = release_metadata
      end

      def project
        ReleaseTools::Project::GitlabCe
      end

      def source_for_target_branch
        'master'
      end
    end

    klass.new(version, client: client)
  end

  describe '#project_path' do
    context 'for a regular release' do
      it 'returns the regular project path' do
        expect(release.project_path).to eq(release.project.path)
      end
    end

    context 'for a security release' do
      it 'returns the security path' do
        ReleaseTools::SharedStatus.as_security_release do
          expect(release.project_path).to eq(release.project.security_path)
        end
      end
    end
  end

  describe '#tag_name' do
    it 'returns the name of the tag to create' do
      expect(release.tag_name).to eq('v1.2.3')
    end
  end

  describe '#target_branch' do
    it 'returns the name of the target branch' do
      expect(release.target_branch).to eq('1-2-stable')
    end
  end

  describe '#create_target_branch' do
    it 'creates the target branch' do
      expect(client)
        .to receive(:find_or_create_branch)
        .with('1-2-stable', 'master', release.project_path)

      release.create_target_branch
    end
  end

  describe '#notify_slack' do
    it 'sends a notification to Slack' do
      expect(ReleaseTools::Slack::TagNotification)
        .to receive(:release)
        .with(release.project, release.version)

      release.notify_slack(release.project, release.version)
    end
  end

  describe '#commit_version_files' do
    context 'when a version file exists' do
      it 'updates it' do
        branch = 'master'

        allow(client)
          .to receive(:file_contents)
          .with(release.project_path, 'VERSION', branch)
          .and_return("1.2.3\n")

        allow(client)
          .to receive(:create_commit)
          .with(
            release.project_path,
            branch,
            'Update VERSION files',
            [{ action: 'update', file_path: 'VERSION', content: '4.5.6' }]
          )

        release.commit_version_files(branch, { 'VERSION' => '4.5.6' })

        expect(client).to have_received(:create_commit)
      end

      it 'supports skipping of CI builds' do
        branch = 'master'

        allow(client)
          .to receive(:file_contents)
          .with(release.project_path, 'VERSION', branch)
          .and_return("1.2.3\n")

        allow(client)
          .to receive(:create_commit)
          .with(
            release.project_path,
            branch,
            "Update VERSION files\n\n[ci skip]",
            [{ action: 'update', file_path: 'VERSION', content: '4.5.6' }]
          )

        release
          .commit_version_files(branch, { 'VERSION' => '4.5.6' }, skip_ci: true)

        expect(client).to have_received(:create_commit)
      end

      it 'supports skipping of Merge Train syncs' do
        branch = 'master'

        allow(client)
          .to receive(:file_contents)
          .with(release.project_path, 'VERSION', branch)
          .and_return("1.2.3\n")

        allow(client)
          .to receive(:create_commit)
          .with(
            release.project_path,
            branch,
            "Update VERSION files\n\n[merge-train skip]",
            [{ action: 'update', file_path: 'VERSION', content: '4.5.6' }]
          )

        release.commit_version_files(
          branch,
          { 'VERSION' => '4.5.6' },
          skip_merge_train: true
        )

        expect(client).to have_received(:create_commit)
      end

      it 'supports skipping of Merge Train syncs and CI builds' do
        branch = 'master'

        allow(client)
          .to receive(:file_contents)
          .with(release.project_path, 'VERSION', branch)
          .and_return("1.2.3\n")

        allow(client)
          .to receive(:create_commit)
          .with(
            release.project_path,
            branch,
            "Update VERSION files\n\n[ci skip]\n[merge-train skip]",
            [{ action: 'update', file_path: 'VERSION', content: '4.5.6' }]
          )

        release.commit_version_files(
          branch,
          { 'VERSION' => '4.5.6' },
          skip_ci: true,
          skip_merge_train: true
        )

        expect(client).to have_received(:create_commit)
      end
    end

    context 'when a version file does not exist' do
      it 'creates it' do
        branch = 'master'

        allow(client)
          .to receive(:file_contents)
          .and_raise(gitlab_error(:NotFound))

        allow(client)
          .to receive(:create_commit)
          .with(
            release.project_path,
            branch,
            'Update VERSION files',
            [{ action: 'create', file_path: 'VERSION', content: '4.5.6' }]
          )

        release.commit_version_files(branch, { 'VERSION' => '4.5.6' })

        expect(client).to have_received(:create_commit)
      end
    end

    context 'when there are no changes' do
      it 'does not commit anything' do
        branch = 'master'

        allow(client)
          .to receive(:file_contents)
          .with(release.project_path, 'VERSION', branch)
          .and_return("4.5.6\n")

        allow(client).to receive(:create_commit)

        release.commit_version_files(branch, { 'VERSION' => '4.5.6' })

        expect(client).not_to have_received(:create_commit)
      end
    end

    context 'when there are no changes but the new version contains a trailing newline' do
      it 'does not commit anything' do
        branch = 'master'

        allow(client)
          .to receive(:file_contents)
          .with(release.project_path, 'VERSION', branch)
          .and_return("4.5.6\n")

        allow(client).to receive(:create_commit)

        release.commit_version_files(branch, { 'VERSION' => "4.5.6\n" })

        expect(client).not_to have_received(:create_commit)
      end
    end
  end

  describe '#last_production_commit' do
    context 'when there are production deployments' do
      it 'returns the SHA of the last deployment' do
        expect(client)
          .to receive(:deployments)
          .with(release.project.path, 'gprd')
          .and_return([double(:deploy, sha: '123')])

        expect(release.last_production_commit).to eq('123')
      end
    end

    context 'when there are no production deployments' do
      it 'raises RuntimeError' do
        expect(client)
          .to receive(:deployments)
          .with(release.project.path, 'gprd')
          .and_return([])

        expect { release.last_production_commit }.to raise_error(RuntimeError)
      end
    end
  end
end
