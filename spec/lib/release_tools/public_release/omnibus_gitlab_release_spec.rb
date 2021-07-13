# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PublicRelease::OmnibusGitlabRelease do
  describe '#initialize' do
    it 'raises ArgumentError when the input version is not an EE version' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ce')

      expect { described_class.new(version) }.to raise_error(ArgumentError)
    end

    it 'does not raise an error when the input version is an EE version' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')

      expect { described_class.new(version) }.not_to raise_error
    end
  end

  describe '#execute' do
    it 'runs the release' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
      release = described_class.new(version)
      ce_tag = double(:tag, name: 'v42.0.0.ee')
      ee_tag = double(:tag, name: 'v42.0.0.ce')

      expect(release).to receive(:verify_version_file)
      expect(release).to receive(:create_target_branch)
      expect(release).to receive(:compile_changelog)
      expect(release).to receive(:update_component_versions)
      expect(release).to receive(:create_ce_tag).and_return(ce_tag)
      expect(release).to receive(:create_ee_tag).and_return(ee_tag)
      expect(release).to receive(:notify_slack)

      expect(release)
        .to receive(:add_release_data_for_tags)
        .with(ce_tag, ee_tag)

      release.execute
    end
  end

  describe '#verify_version_file' do
    context 'when the GitLab VERSION file equals the released GitLab version' do
      it 'does not raise an error' do
        version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
        release = described_class.new(version)

        expect(release)
          .to receive(:read_version)
          .with('gitlab-org/gitlab', 'VERSION', '42-0-stable-ee')
          .and_return(ReleaseTools::Version.new('42.0.0-ee'))

        expect { release.verify_version_file }.not_to raise_error
      end
    end

    context 'when the GitLab VERSION file is different from the released GitLab version' do
      it 'does raises RuntimeError' do
        version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
        release = described_class.new(version)

        expect(release)
          .to receive(:read_version)
          .with('gitlab-org/gitlab', 'VERSION', '42-0-stable-ee')
          .and_return(ReleaseTools::Version.new('41.0.0-ee'))

        expect { release.verify_version_file }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#compile_changelog' do
    it 'compiles the changelog' do
      client = class_spy(ReleaseTools::GitlabClient)
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
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
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0+rc42.ee')
      release = described_class.new(version, client: client)

      expect(ReleaseTools::ChangelogCompiler).not_to receive(:new)

      release.compile_changelog
    end
  end

  describe '#create_ce_tag' do
    it 'creates the tag for CE' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
      release = described_class.new(version)

      expect(release)
        .to receive(:find_or_create_tag)
        .with(version.to_ce.tag, release.ce_project_path, '42-0-stable')

      release.create_ce_tag
    end
  end

  describe '#create_ee_tag' do
    it 'creates the tag for EE' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
      release = described_class.new(version)

      expect(release)
        .to receive(:find_or_create_tag)
        .with(version.tag, release.ee_project_path, '42-0-stable-ee')

      release.create_ee_tag
    end
  end

  describe '#find_or_create_tag' do
    let(:version) { ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee') }
    let(:release) { described_class.new(version) }

    context 'when the tag already exists' do
      it 'returns the tag' do
        tag = double(:tag)

        allow(release.client)
          .to receive(:tag)
          .with(release.project_path, tag: 'foo')
          .and_return(tag)

        expect(release).not_to receive(:update_version_file)

        expect(release.find_or_create_tag('foo', 'project', 'branch'))
          .to eq(tag)
      end
    end

    context 'when there is a response error' do
      it 'retries the operation' do
        tag = double(:tag)
        raised = false

        allow(release.client).to receive(:tag) do
          if raised
            tag
          else
            raised = true
            raise gitlab_error(:InternalServerError)
          end
        end

        expect(release).not_to receive(:update_version_file)

        expect(release.find_or_create_tag('foo', 'project', 'branch'))
          .to eq(tag)
      end
    end

    context 'when the tag does not exist' do
      it 'updates the VERSION file and creates a tag' do
        tag = double(:tag)

        allow(release.client)
          .to receive(:tag)
          .with(release.project_path, tag: 'foo')
          .and_raise(gitlab_error(:NotFound))

        expect(release)
          .to receive(:read_version)
          .with('project', 'VERSION', 'branch')
          .and_return('1.2.3')

        expect(release)
          .to receive(:update_version_file)
          .with('1.2.3')

        expect(release.client)
          .to receive(:create_tag)
          .with(release.project_path, 'foo', release.target_branch, 'Version foo')
          .and_return(tag)

        expect(release.find_or_create_tag('foo', 'project', 'branch'))
          .to eq(tag)
      end
    end
  end

  describe '#update_component_versions' do
    it 'updates the component version files according to the GitLab EE repository' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
      release = described_class.new(version)
      branch = '42-0-stable-ee'

      versions = {
        'GITALY_SERVER_VERSION' => '1.0.0',
        'GITLAB_PAGES_VERSION' => '2.0.0',
        'GITLAB_SHELL_VERSION' => '3.0.0',
        'GITLAB_ELASTICSEARCH_INDEXER_VERSION' => '5.0.0',
        'GITLAB_KAS_VERSION' => '6.0.0'
      }

      versions.each do |file, content|
        expect(release)
          .to receive(:read_version)
          .with(release.ee_project_path, file, branch)
          .and_return(ReleaseTools::Version.new(content))
      end

      expect(release)
        .to receive(:commit_version_files)
        .with('42-0-stable', versions, message: an_instance_of(String))

      release.update_component_versions
    end

    context 'when releasing a version prior to 13.10.0' do
      it 'includes the Workhorse version' do
        version = ReleaseTools::OmnibusGitlabVersion.new('13.9.4.ee')
        release = described_class.new(version)
        branch = '13-9-stable-ee'

        versions = {
          'GITALY_SERVER_VERSION' => '1.0.0',
          'GITLAB_PAGES_VERSION' => '2.0.0',
          'GITLAB_SHELL_VERSION' => '3.0.0',
          'GITLAB_WORKHORSE_VERSION' => '4.0.0',
          'GITLAB_ELASTICSEARCH_INDEXER_VERSION' => '5.0.0',
          'GITLAB_KAS_VERSION' => '6.0.0'
        }

        versions.each do |file, content|
          expect(release)
            .to receive(:read_version)
            .with(release.ee_project_path, file, branch)
            .and_return(ReleaseTools::Version.new(content))
        end

        expect(release)
          .to receive(:commit_version_files)
          .with('13-9-stable', versions, message: an_instance_of(String))

        release.update_component_versions
      end
    end

    context 'when releasing a version for 13.10.0' do
      it 'does not include the Workhorse version' do
        version = ReleaseTools::OmnibusGitlabVersion.new('13.10.0.ee')
        release = described_class.new(version)
        branch = '13-10-stable-ee'

        versions = {
          'GITALY_SERVER_VERSION' => '1.0.0',
          'GITLAB_PAGES_VERSION' => '2.0.0',
          'GITLAB_SHELL_VERSION' => '3.0.0',
          'GITLAB_ELASTICSEARCH_INDEXER_VERSION' => '5.0.0',
          'GITLAB_KAS_VERSION' => '6.0.0'
        }

        versions.each do |file, content|
          expect(release)
            .to receive(:read_version)
            .with(release.ee_project_path, file, branch)
            .and_return(ReleaseTools::Version.new(content))
        end

        expect(release)
          .to receive(:commit_version_files)
          .with('13-10-stable', versions, message: an_instance_of(String))

        release.update_component_versions
      end
    end
  end

  describe '#update_version_files' do
    it 'updates a version file' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
      release = described_class.new(version)

      expect(release).to receive(:commit_version_files).with(
        '42-0-stable',
        { 'VERSION' => '42.0.0-ee' },
        message: an_instance_of(String)
      )

      release.update_version_file('42.0.0-ee')
    end
  end

  describe '#add_release_data_for_tags' do
    it 'adds the release data for Omnibus CE and EE' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
      release = described_class.new(version)
      ce_tag = double(:tag, name: 'foo', commit: double(:commit, id: 'a'))
      ee_tag = double(:tag, name: 'bar', commit: double(:commit, id: 'b'))

      expect(release.release_metadata).to receive(:add_release).with(
        name: 'omnibus-gitlab-ce',
        version: '42.0.0',
        sha: 'a',
        ref: 'foo',
        tag: true
      )

      expect(release.release_metadata).to receive(:add_release).with(
        name: 'omnibus-gitlab-ee',
        version: '42.0.0',
        sha: 'b',
        ref: 'bar',
        tag: true
      )

      release.add_release_data_for_tags(ce_tag, ee_tag)
    end
  end

  describe '#read_version' do
    it 'reads a version file from a project' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
      release = described_class.new(version)

      expect(release.client)
        .to receive(:file_contents)
        .with(ReleaseTools::Project::GitlabEe, 'VERSION', 'master')
        .and_return("1.2.3\n")

      version = release
        .read_version(ReleaseTools::Project::GitlabEe, 'VERSION', 'master')

      expect(version).to eq('1.2.3')
    end

    it 'retries the operation if it fails' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
      release = described_class.new(version)
      raised = false

      allow(release.client).to receive(:file_contents) do
        if raised
          '1.2.3'
        else
          raised = true
          raise gitlab_error(:InternalServerError)
        end
      end

      version = release
        .read_version(ReleaseTools::Project::GitlabEe, 'VERSION', 'master')

      expect(version).to eq('1.2.3')
    end
  end

  describe '#project' do
    it 'returns the project to release' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
      release = described_class.new(version)

      expect(release.project).to eq(ReleaseTools::Project::OmnibusGitlab)
    end
  end

  describe '#ee_stable_branch' do
    it 'returns the GitLab EE stable branch' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
      release = described_class.new(version)

      expect(release.ee_stable_branch).to eq('42-0-stable-ee')
    end
  end

  describe '#ce_stable_branch' do
    it 'returns the GitLab CE stable branch' do
      version = ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee')
      release = described_class.new(version)

      expect(release.ce_stable_branch).to eq('42-0-stable')
    end
  end

  describe '#source_for_target_branch' do
    let(:version) { ReleaseTools::OmnibusGitlabVersion.new('42.0.0.ee') }

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
