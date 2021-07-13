# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PublicRelease::GitlabRelease do
  describe '#initialize' do
    it 'converts CE versions to EE versions' do
      version = ReleaseTools::Version.new('42.0.0')
      release = described_class.new(version)

      expect(release.version).to eq('42.0.0-ee')
    end
  end

  describe '#execute' do
    it 'runs the release' do
      version = ReleaseTools::Version.new('42.0.0-ee')
      release = described_class.new(version)
      ce_tag = double(:tag, name: 'v42.0.0')
      ee_tag = double(:tag, name: 'v42.0.0-ee')

      expect(release).to receive(:create_ce_target_branch)
      expect(release).to receive(:create_ee_target_branch)

      expect(release).to receive(:update_gitaly_server_version)
      expect(release).to receive(:compile_changelogs)
      expect(release).to receive(:update_versions)
      expect(release).to receive(:wait_for_ee_to_ce_sync)
      expect(release).to receive(:create_ce_commit_to_run_ci)

      expect(release).to receive(:create_ce_tag).and_return(ce_tag)
      expect(release).to receive(:create_ee_tag).and_return(ee_tag)

      expect(release).to receive(:start_new_minor_release)

      expect(release)
        .to receive(:add_release_data_for_tags)
        .with(ce_tag, ee_tag)

      expect(release)
        .to receive(:notify_slack)
        .with(ReleaseTools::Project::GitlabCe, version.to_ce)

      expect(release)
        .to receive(:notify_slack)
        .with(ReleaseTools::Project::GitlabEe, version)

      release.execute
    end
  end

  describe '#create_ce_target_branch' do
    it 'creates the CE target branch from the last stable branch' do
      client = class_spy(ReleaseTools::GitlabClient)
      version = ReleaseTools::Version.new('42.1.0-ee')
      release = described_class.new(version, client: client)

      expect(client)
        .to receive(:find_or_create_branch)
        .with('42-1-stable', '42-0-stable', release.ce_project_path)

      release.create_ce_target_branch
    end
  end

  describe '#create_ee_target_branch' do
    context 'when a custom commit is specified' do
      it 'creates the EE target branch from the custom commit' do
        client = class_spy(ReleaseTools::GitlabClient)
        version = ReleaseTools::Version.new('42.1.0-ee')
        release = described_class.new(version, client: client, commit: 'foo')

        expect(client)
          .to receive(:find_or_create_branch)
          .with('42-1-stable-ee', 'foo', release.project_path)

        release.create_ee_target_branch
      end
    end

    context "when a custom commit isn't specified" do
      it 'creates the EE target branch from the last production commit' do
        client = class_spy(ReleaseTools::GitlabClient)
        version = ReleaseTools::Version.new('42.1.0-ee')
        release = described_class.new(version, client: client)

        expect(release)
          .to receive(:last_production_commit)
          .and_return('123abc')

        expect(client)
          .to receive(:find_or_create_branch)
          .with('42-1-stable-ee', '123abc', release.project_path)

        release.create_ee_target_branch
      end
    end
  end

  describe '#update_gitaly_server_version' do
    context 'when releasing an RC' do
      it 'does nothing' do
        version = ReleaseTools::Version.new('42.1.0-rc42-ee')
        release = described_class.new(version)

        expect(release).not_to receive(:commit_version_files)

        release.update_gitaly_server_version
      end
    end

    context 'when releasing a non-RC release' do
      it 'updates GITALY_SERVER_VERSION on the stable branch' do
        version = ReleaseTools::Version.new('42.1.0-ee')
        release = described_class.new(version)

        expect(release.client)
          .to receive(:file_contents)
          .with('gitlab-org/gitaly', 'VERSION', '42-1-stable')
          .and_return('9.0.0')

        expect(release)
          .to receive(:commit_version_files)
          .with(
            '42-1-stable-ee',
            { 'GITALY_SERVER_VERSION' => '9.0.0' },
            message: 'Update Gitaly version to 9.0.0',
            skip_ci: true
          )

        release.update_gitaly_server_version
      end
    end
  end

  describe '#wait_for_ee_to_ce_sync' do
    before do
      pipeline = double(:pipeline, web_url: 'foo', id: 1)

      allow(ReleaseTools::GitlabOpsClient.client)
        .to receive(:create_pipeline)
        .with(
          'gitlab-org/merge-train',
          'master',
          MERGE_FOSS: '1',
          SOURCE_PROJECT: 'gitlab-org/gitlab',
          SOURCE_BRANCH: '42-1-stable-ee',
          TARGET_PROJECT: 'gitlab-org/gitlab-foss',
          TARGET_BRANCH: '42-1-stable'
        )
        .and_return(pipeline)
    end

    it 'returns when EE has been synced to CE' do
      pipeline = double(:pipeline, status: 'success')
      version = ReleaseTools::Version.new('42.1.0-ee')
      release = described_class.new(version)

      expect(ReleaseTools::GitlabOpsClient)
        .to receive(:pipeline)
        .with('gitlab-org/merge-train', 1)
        .and_return(pipeline)

      expect { release.wait_for_ee_to_ce_sync }.not_to raise_error
    end

    it 'raises when the pipeline fails' do
      pipeline = double(:pipeline, status: 'failed')
      version = ReleaseTools::Version.new('42.1.0-ee')
      release = described_class.new(version)

      expect(ReleaseTools::GitlabOpsClient)
        .to receive(:pipeline)
        .with('gitlab-org/merge-train', 1)
        .and_return(pipeline)

      expect { release.wait_for_ee_to_ce_sync }
        .to raise_error(described_class::PipelineFailed)
    end

    it 'raises when the pipeline does not succeed in a timely manner' do
      pipeline = double(:pipeline, status: 'running')
      version = ReleaseTools::Version.new('42.1.0-ee')
      release = described_class.new(version)

      stub_const(
        'ReleaseTools::PublicRelease::GitlabRelease::WAIT_SYNC_INTERVALS',
        Array.new(15, 0)
      )

      expect(ReleaseTools::GitlabOpsClient)
        .to receive(:pipeline)
        .with('gitlab-org/merge-train', 1)
        .exactly(16)
        .times
        .and_return(pipeline)

      expect { release.wait_for_ee_to_ce_sync }
        .to raise_error(described_class::PipelineTooSlow)
    end

    it 'retries the operation when the pipeline is still running' do
      version = ReleaseTools::Version.new('42.1.0-ee')
      release = described_class.new(version)

      stub_const(
        'ReleaseTools::PublicRelease::GitlabRelease::WAIT_SYNC_INTERVALS',
        Array.new(15, 0)
      )

      expect(ReleaseTools::GitlabOpsClient)
        .to receive(:pipeline)
        .with('gitlab-org/merge-train', 1)
        .twice
        .and_return(
          double(:pipeline, status: 'running'),
          double(:pipeline, status: 'success')
        )

      expect { release.wait_for_ee_to_ce_sync }.not_to raise_error
    end
  end

  describe '#create_ce_commit_to_run_ci' do
    let(:release) { described_class.new(ReleaseTools::Version.new('42.1.0-ee')) }

    context 'when the last commit includes "ci skip"' do
      it 'creates a new empty commit' do
        commit = double(:commit, message: "Foo\n[ci skip]")

        expect(release.client)
          .to receive(:commit)
          .with('gitlab-org/gitlab-foss', ref: '42-1-stable')
          .and_return(commit)

        expect(release.client)
          .to receive(:create_commit)
          .with(
            'gitlab-org/gitlab-foss',
            '42-1-stable',
            an_instance_of(String),
            [
              {
                action: 'update',
                file_path: 'VERSION',
                content: '42.1.0'
              }
            ]
          )

        release.create_ce_commit_to_run_ci
      end
    end

    context "when the last commit doesn't include \"ci skip\"" do
      it "doesn't create a new commit" do
        commit = double(:commit, message: 'Bump version to X')

        expect(release.client)
          .to receive(:commit)
          .with('gitlab-org/gitlab-foss', ref: '42-1-stable')
          .and_return(commit)

        expect(release.client).not_to receive(:create_commit)

        release.create_ce_commit_to_run_ci
      end
    end
  end

  describe '#compile_changelogs' do
    it 'compiles the changelog for a stable release' do
      client = class_spy(ReleaseTools::GitlabClient)
      version = ReleaseTools::Version.new('42.0.0-ee')
      release = described_class.new(version, client: client)
      compiler = instance_spy(ReleaseTools::ChangelogCompiler)

      expect(ReleaseTools::ChangelogCompiler)
        .to receive(:new)
        .with(release.project.canonical_or_security_path, client: client)
        .and_return(compiler)

      expect(compiler)
        .to receive(:compile)
        .with(version, branch: '42-0-stable-ee')

      release.compile_changelogs
    end

    it 'does not compile the changelog for an RC' do
      client = class_spy(ReleaseTools::GitlabClient)
      version = ReleaseTools::Version.new('42.0.0-rc42-ee')
      release = described_class.new(version, client: client)

      expect(ReleaseTools::ChangelogCompiler).not_to receive(:new)

      release.compile_changelogs
    end
  end

  describe '#update_versions' do
    it 'updates the VERSION files for CE and EE' do
      version = ReleaseTools::Version.new('42.0.0-ee')
      release = described_class.new(version)

      expect(release)
        .to receive(:commit_version_files)
        .with(
          '42-0-stable-ee',
          { 'VERSION' => '42.0.0-ee' },
          skip_ci: false,
          skip_merge_train: true
        )

      expect(release)
        .to receive(:commit_version_files)
        .with(
          '42-0-stable',
          { 'VERSION' => '42.0.0' },
          project: release.ce_project_path,
          skip_ci: true
        )

      release.update_versions
    end
  end

  describe '#start_new_minor_release' do
    context 'when releasing a patch release' do
      it 'does nothing' do
        version = ReleaseTools::Version.new('42.1.1-ee')
        release = described_class.new(version)

        expect(release).not_to receive(:commit_version_files)

        release.start_new_minor_release
      end
    end

    context 'when releasing a new minor release' do
      it 'updates the VERSION files on the source branches' do
        version = ReleaseTools::Version.new('42.0.0-ee')
        release = described_class.new(version)

        expect(release)
          .to receive(:commit_version_files)
          .with('master', { 'VERSION' => '42.1.0-pre' }, skip_ci: true)

        expect(release)
          .to receive(:commit_version_files)
          .with(
            'master',
            { 'VERSION' => '42.1.0-pre' },
            project: release.ce_project_path,
            skip_ci: true
          )

        release.start_new_minor_release
      end
    end
  end

  describe '#create_ce_tag' do
    it 'creates the tag for CE' do
      version = ReleaseTools::Version.new('42.0.0-ee')
      release = described_class.new(version)

      expect(release.client)
        .to receive(:find_or_create_tag)
        .with(
          release.ce_project_path,
          version.to_ce.tag,
          '42-0-stable',
          message: 'Version v42.0.0'
        )

      release.create_ce_tag
    end
  end

  describe '#create_ee_tag' do
    it 'creates the tag for EE' do
      version = ReleaseTools::Version.new('42.0.0-ee')
      release = described_class.new(version)

      expect(release.client)
        .to receive(:find_or_create_tag)
        .with(
          release.project_path,
          version.tag,
          '42-0-stable-ee',
          message: 'Version v42.0.0-ee'
        )

      release.create_ee_tag
    end
  end

  describe '#add_release_data_for_tags' do
    it 'adds the release data for CE and EE' do
      version = ReleaseTools::Version.new('42.0.0-ee')
      release = described_class.new(version)
      ce_tag = double(:tag, name: 'foo', commit: double(:commit, id: 'a'))
      ee_tag = double(:tag, name: 'bar', commit: double(:commit, id: 'b'))

      expect(release.release_metadata).to receive(:add_release).with(
        name: 'gitlab-ce',
        version: '42.0.0',
        sha: 'a',
        ref: 'foo',
        tag: true
      )

      expect(release.release_metadata).to receive(:add_release).with(
        name: 'gitlab-ee',
        version: '42.0.0',
        sha: 'b',
        ref: 'bar',
        tag: true
      )

      release.add_release_data_for_tags(ce_tag, ee_tag)
    end
  end

  describe '#project' do
    it 'returns the project to release' do
      version = ReleaseTools::Version.new('42.0.0-ee')
      release = described_class.new(version)

      expect(release.project).to eq(ReleaseTools::Project::GitlabEe)
    end
  end

  describe '#ce_target_branch' do
    it 'returns the target branch for CE' do
      version = ReleaseTools::Version.new('42.0.0-ee')
      release = described_class.new(version)

      expect(release.ce_target_branch).to eq('42-0-stable')
    end
  end

  describe '#ce_project_path' do
    it 'returns the path to CE' do
      version = ReleaseTools::Version.new('42.0.0-ee')
      release = described_class.new(version)

      expect(release.ce_project_path)
        .to eq(ReleaseTools::Project::GitlabCe.canonical_or_security_path)
    end
  end

  describe '#source_for_target_branch' do
    let(:version) { ReleaseTools::Version.new('42.0.0-ee') }

    context 'when a custom commit is specified' do
      it 'returns the commit' do
        release = described_class.new(version, commit: 'foo')

        expect(release.source_for_target_branch).to eq('foo')
      end
    end

    context 'when no custom commit is specified' do
      it 'returns the SHA of the last deployment' do
        release = described_class.new(version)

        allow(release).to receive(:last_production_commit).and_return('foo')

        expect(release.source_for_target_branch).to eq('foo')
      end
    end
  end
end
