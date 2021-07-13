# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PublicRelease::HelmGitlabRelease do
  let(:version) { ReleaseTools::Version.new('1.0.0') }
  let(:gitlab_version) { ReleaseTools::Version.new('2.0.0-ee') }
  let(:release) { described_class.new(version, gitlab_version) }

  describe '#execute' do
    context 'when releasing a Helm RC' do
      let(:gitlab_version) { ReleaseTools::Version.new('2.0.0-rc42-ee') }

      it 'does nothing' do
        expect(release).not_to receive(:create_target_branch)

        release.execute
      end
    end

    context 'when releasing a stable release' do
      it 'performs the release' do
        tag = double(:tag, name: 'v1.0.0')

        expect(release).to receive(:create_target_branch)
        expect(release).to receive(:compile_changelog)
        expect(release).to receive(:update_versions)
        expect(release).to receive(:update_version_mapping)
        expect(release).to receive(:create_tag).and_return(tag)
        expect(release).to receive(:add_release_metadata).with(tag)
        expect(release).to receive(:notify_slack).with(release.project, version)

        release.execute
      end
    end
  end

  describe '#compile_changelog' do
    it 'compiles the changelog' do
      compiler = instance_spy(ReleaseTools::ChangelogCompiler)

      expect(ReleaseTools::ChangelogCompiler)
        .to receive(:new)
        .with(release.project_path, client: release.client)
        .and_return(compiler)

      expect(compiler)
        .to receive(:compile)
        .with(version, branch: release.target_branch)

      release.compile_changelog
    end
  end

  describe '#update_versions' do
    it 'verifies and updates the Chart versions' do
      stable_files = %w[Chart.yaml]
      default_files = %w[Chart.yaml foo/Chart.yaml]

      expect(release).to receive(:all_chart_files).and_return(stable_files)

      expect(release)
        .to receive(:all_chart_files)
        .with(described_class::DEFAULT_BRANCH)
        .and_return(default_files)

      expect(release).to receive(:verify_chart_files).with(stable_files)
      expect(release).to receive(:verify_chart_files).with(default_files)
      expect(release).to receive(:update_chart_files).with(stable_files)
      expect(release).to receive(:update_default_chart_files).with(default_files)

      release.update_versions
    end
  end

  describe '#verify_chart_files' do
    context 'when there is an unrecognised chart' do
      it 'raises StandardError' do
        expect { release.verify_chart_files(%w[foo/Chart.yaml]) }
          .to raise_error(StandardError)
      end
    end

    context 'when all charts are recognised' do
      it 'does not raise any errors' do
        expect do
          release.verify_chart_files(%w[charts/gitlab/charts/gitaly/Chart.yaml])
        end.not_to raise_error
      end
    end
  end

  describe '#update_chart_files' do
    let(:gemfile) do
      File.read("#{VersionFixture.new.fixture_path}/Gemfile.lock")
    end

    before do
      allow(release)
        .to receive(:read_ee_file)
        .with('Gemfile.lock')
        .and_return(gemfile)
    end

    it 'supports application versions based on the GitLab version' do
      path = 'charts/gitlab/charts/webservice/Chart.yaml'
      old_yaml = YAML.dump(
        'name' => 'webservice',
        'version' => '0.1.0',
        'appVersion' => '0.1.1'
      )

      new_yaml = YAML.dump(
        'name' => 'webservice',
        'version' => '1.0.0',
        'appVersion' => '2.0.0'
      )

      expect(release).to receive(:read_file).with(path).and_return(old_yaml)

      expect(release).to receive(:commit_version_files).with(
        release.target_branch,
        { path => new_yaml },
        message: "Update Chart versions to 1.0.0\n\n[ci skip]"
      )

      release.update_chart_files([path])
    end

    it 'supports application versions based on a Gem version' do
      path = 'charts/gitlab/charts/mailroom/Chart.yaml'
      old_yaml = YAML.dump(
        'name' => 'mailroom',
        'version' => '0.1.0',
        'appVersion' => '0.1.1'
      )

      new_yaml = YAML.dump(
        'name' => 'mailroom',
        'version' => '1.0.0',
        'appVersion' => '0.9.1'
      )

      expect(release).to receive(:read_file).with(path).and_return(old_yaml)

      expect(release).to receive(:commit_version_files).with(
        release.target_branch,
        { path => new_yaml },
        message: "Update Chart versions to 1.0.0\n\n[ci skip]"
      )

      release.update_chart_files([path])
    end

    it 'supports application versions based on a VERSION file' do
      path = 'charts/gitlab/charts/gitaly/Chart.yaml'
      old_yaml = YAML.dump(
        'name' => 'gitaly',
        'version' => '0.1.0',
        'appVersion' => '0.1.1'
      )

      new_yaml = YAML.dump(
        'name' => 'gitaly',
        'version' => '1.0.0',
        'appVersion' => '5.0.0'
      )

      expect(release).to receive(:read_file).with(path).and_return(old_yaml)

      expect(release)
        .to receive(:read_ee_file)
        .with(ReleaseTools::Project::Gitaly.version_file)
        .and_return('5.0.0')

      expect(release).to receive(:commit_version_files).with(
        release.target_branch,
        { path => new_yaml },
        message: "Update Chart versions to 1.0.0\n\n[ci skip]"
      )

      release.update_chart_files([path])
    end

    it 'supports unmanaged application versions' do
      path = 'charts/gitlab/charts/gitlab-exporter/Chart.yaml'
      old_yaml = YAML.dump(
        'name' => 'gitlab-exporter',
        'version' => '0.1.0',
        'appVersion' => '0.1.1'
      )

      new_yaml = YAML.dump(
        'name' => 'gitlab-exporter',
        'version' => '1.0.0',
        'appVersion' => '0.1.1'
      )

      expect(release).to receive(:read_file).with(path).and_return(old_yaml)

      expect(release).to receive(:commit_version_files).with(
        release.target_branch,
        { path => new_yaml },
        message: "Update Chart versions to 1.0.0\n\n[ci skip]"
      )

      release.update_chart_files([path])
    end
  end

  describe '#update_default_chart_files' do
    let(:path) { 'charts/gitlab/charts/gitaly/Chart.yaml' }

    context 'when the release version is newer than the existing version' do
      it 'updates the version field' do
        old_yaml = YAML.dump(
          'name' => 'gitaly',
          'version' => '0.1.0',
          'appVersion' => '0.1.1'
        )

        new_yaml = YAML.dump(
          'name' => 'gitaly',
          'version' => '1.0.0',
          'appVersion' => '0.1.1'
        )

        allow(release)
          .to receive(:read_file)
          .with(path, branch: described_class::DEFAULT_BRANCH)
          .and_return(old_yaml)

        expect(release).to receive(:commit_version_files).with(
          described_class::DEFAULT_BRANCH,
          { path => new_yaml },
          message: "Update Chart versions to 1.0.0\n\n[ci skip]"
        )

        release.update_default_chart_files([path])
      end
    end

    context 'when the existing version is newer than the release version' do
      it 'does not update the version field' do
        old_yaml = YAML.dump(
          'name' => 'gitaly',
          'version' => '2.0.0',
          'appVersion' => '0.1.1'
        )

        allow(release)
          .to receive(:read_file)
          .with(path, branch: described_class::DEFAULT_BRANCH)
          .and_return(old_yaml)

        expect(release).to receive(:commit_version_files).with(
          described_class::DEFAULT_BRANCH,
          {},
          message: "Update Chart versions to 1.0.0\n\n[ci skip]"
        )

        release.update_default_chart_files([path])
      end
    end
  end

  describe '#update_version_mapping' do
    it 'updates the version mapping on the stable and default branches' do
      expect(release)
        .to receive(:update_version_mapping_on_branch)
        .with('1-0-stable')

      expect(release)
        .to receive(:update_version_mapping_on_branch)
        .with(described_class::DEFAULT_BRANCH)

      release.update_version_mapping
    end
  end

  describe '#update_version_mapping_on_branch' do
    it 'updates the version mapping document' do
      old_markdown = <<~MARKDOWN
        foo

        | Chart version | GitLab version |
        |---------------|----------------|
        | 0.2.0 | 1.0.0
        | 0.1.0 | 1.0.0

        bar
      MARKDOWN

      new_markdown = <<~MARKDOWN
        foo

        | Chart version | GitLab version |
        |---------------|----------------|
        | 1.0.0 | 2.0.0 |
        | 0.2.0 | 1.0.0 |
        | 0.1.0 | 1.0.0 |

        bar
      MARKDOWN

      expect(release)
        .to receive(:read_file)
        .with(described_class::VERSION_MAPPING_FILE, branch: 'foo')
        .and_return(old_markdown)

      expect(release)
        .to receive(:commit_version_files)
        .with(
          'foo',
          { described_class::VERSION_MAPPING_FILE => new_markdown },
          message: 'Update version mapping for 1.0.0'
        )

      release.update_version_mapping_on_branch('foo')
    end
  end

  describe '#create_tag' do
    it 'creates the tag' do
      expect(release.client)
        .to receive(:find_or_create_tag)
        .with(
          release.project_path,
          release.tag_name,
          release.target_branch,
          message: 'Version v1.0.0 - contains GitLab EE 2.0.0'
        )

      release.create_tag
    end
  end

  describe '#add_release_metadata' do
    it 'adds the release metadata' do
      tag = double(:tag, name: 'v1.0.0', commit: double(:commit, id: 'a'))

      expect(release.release_metadata).to receive(:add_release).with(
        name: 'helm-gitlab',
        version: '1.0.0',
        sha: 'a',
        ref: 'v1.0.0',
        tag: true
      )

      release.add_release_metadata(tag)
    end
  end

  describe '#read_file' do
    it 'reads a file from a branch' do
      expect(release.client)
        .to receive(:file_contents)
        .with(release.project_path, 'README.md', release.target_branch)
        .and_return("foo\n")

      expect(release.read_file('README.md')).to eq('foo')
    end

    it 'retries the operation if it fails' do
      raised = false

      allow(release.client).to receive(:file_contents) do
        if raised
          "foo\n"
        else
          raised = true
          raise gitlab_error(:InternalServerError)
        end
      end

      expect(release.read_file('README.md')).to eq('foo')
    end
  end

  describe '#read_ee_file' do
    it 'reads a file from the GitLab EE repository' do
      expect(release)
        .to receive(:read_file)
        .with('README.md', project: 'gitlab-org/gitlab', branch: '2-0-stable-ee')
        .and_return('foo')

      expect(release.read_ee_file('README.md')).to eq('foo')
    end
  end

  describe '#all_chart_files' do
    it 'returns all the Chart files' do
      entry1 = double(:entry, type: 'blob', path: 'foo')
      entry2 = double(:entry, type: 'tree', path: 'charts/gitlab/charts/bar')

      expect(release.client)
        .to receive(:tree)
        .with(
          release.project_path,
          ref: release.target_branch,
          path: 'charts/gitlab/charts',
          per_page: 100
        )
        .and_return(Gitlab::PaginatedResponse.new([entry1, entry2]))

      expect(release.all_chart_files)
        .to eq(%w[Chart.yaml charts/gitlab/charts/bar/Chart.yaml])
    end

    it 'retries the operation if it fails' do
      entry1 = double(:entry, type: 'blob', path: 'foo')
      entry2 = double(:entry, type: 'tree', path: 'charts/gitlab/charts/bar')
      raised = false

      allow(release.client).to receive(:tree) do
        if raised
          Gitlab::PaginatedResponse.new([entry1, entry2])
        else
          raised = true
          raise gitlab_error(:InternalServerError)
        end
      end

      expect(release.all_chart_files)
        .to eq(%w[Chart.yaml charts/gitlab/charts/bar/Chart.yaml])
    end
  end

  describe '#project' do
    it 'returns the project' do
      expect(release.project).to eq(ReleaseTools::Project::HelmGitlab)
    end
  end

  describe '#source_for_target_branch' do
    context 'when a custom commit is specified' do
      it 'returns the commit' do
        release = described_class.new(version, gitlab_version, commit: 'foo')

        expect(release.source_for_target_branch).to eq('foo')
      end
    end

    context 'when no custom commit is specified' do
      it 'returns the default branch name' do
        release = described_class.new(version, gitlab_version)

        expect(release.source_for_target_branch).to eq(described_class::DEFAULT_BRANCH)
      end
    end
  end

  describe '#version_files_commit_message' do
    it 'returns the commit message' do
      expect(release.version_files_commit_message)
        .to eq("Update Chart versions to 1.0.0\n\n[ci skip]")
    end
  end
end
