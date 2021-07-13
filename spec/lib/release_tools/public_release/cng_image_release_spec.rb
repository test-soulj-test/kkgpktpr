# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PublicRelease::CNGImageRelease do
  let(:version) { ReleaseTools::CNGVersion.new('42.0.0-ee') }
  let(:release) { described_class.new(version) }

  describe '#initialize' do
    it 'converts CE versions to EE versions' do
      version = ReleaseTools::Version.new('42.0.0')
      release = described_class.new(version)

      expect(release.version).to eq('42.0.0-ee')
    end
  end

  describe '#execute' do
    it 'runs the release' do
      ce_tag = double(:tag, name: 'v42.0.0-ce')
      ee_tag = double(:tag, name: 'v42.0.0-ee')
      ubi_tag = double(:tag, name: 'v42.0.0-ubi8')

      expect(release).to receive(:create_target_branch)
      expect(release)
        .to receive(:update_component_versions)
        .and_return([ce_tag, ee_tag, ubi_tag])

      expect(release)
        .to receive(:add_release_data_for_tags)
        .with(ce_tag, ee_tag, ubi_tag)

      expect(release).to receive(:notify_slack)

      release.execute
    end
  end

  describe '#update_component_versions' do
    it 'updates the component versions' do
      ce_data = double(:ce_data)
      ee_data = double(:ee_data)
      ce_tag = double(:ce_tag)
      ee_tag = double(:ee_tag)
      ubi_tag = double(:ubi_tag)

      expect(release)
        .to receive(:distribution_component_versions)
        .and_return([ce_data, ee_data])

      expect(release).to receive(:create_ce_tag).with(ce_data).and_return(ce_tag)
      expect(release).to receive(:create_ee_tag).with(ee_data).and_return(ee_tag)
      expect(release).to receive(:create_ubi_tag).and_return(ubi_tag)

      expect(release.update_component_versions).to eq([ce_tag, ee_tag, ubi_tag])
    end
  end

  describe '#create_ce_tag' do
    it 'creates the CE tag' do
      expect(release)
        .to receive(:find_or_create_tag)
        .with('v42.0.0', {})

      release.create_ce_tag({})
    end
  end

  describe '#create_ee_tag' do
    it 'creates the EE tag' do
      expect(release)
        .to receive(:find_or_create_tag)
        .with('v42.0.0-ee', {})

      release.create_ee_tag({})
    end
  end

  describe '#create_ubi_tag' do
    it 'creates the UBI tag' do
      expect(release.client)
        .to receive(:find_or_create_tag)
        .with(
          release.project_path,
          'v42.0.0-ubi8',
          '42-0-stable',
          message: 'Version v42.0.0-ubi8'
        )

      release.create_ubi_tag
    end
  end

  describe '#find_or_create_tag' do
    let(:version) { ReleaseTools::CNGVersion.new('42.0.0') }
    let(:release) { described_class.new(version) }

    context 'when the tag already exists' do
      it 'returns the tag' do
        tag = double(:tag)

        allow(release.client)
          .to receive(:tag)
          .with(release.project_path, tag: 'foo')
          .and_return(tag)

        expect(release).not_to receive(:commit_version_files)
        expect(release.find_or_create_tag('foo', {})).to eq(tag)
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

        expect(release).not_to receive(:commit_version_files)
        expect(release.find_or_create_tag('foo', {})).to eq(tag)
      end
    end

    context 'when the tag does not exist' do
      it 'updates the variables file and creates a tag' do
        tag = double(:tag)

        allow(release.client)
          .to receive(:tag)
          .with(release.project_path, tag: 'foo')
          .and_raise(gitlab_error(:NotFound))

        expect(release)
          .to receive(:commit_version_files)
          .with(
            '42-0-stable',
            described_class::VARIABLES_FILE => YAML.dump('variables' => {})
          )

        expect(release.client)
          .to receive(:create_tag)
          .with(
            release.project_path,
            'foo',
            release.target_branch,
            'Version foo'
          )
          .and_return(tag)

        expect(release.find_or_create_tag('foo', { 'variables' => {} }))
          .to eq(tag)
      end
    end
  end

  describe '#distribution_component_versions' do
    it 'returns the component versions for CE and EE' do
      allow(release)
        .to receive(:component_versions)
        .and_return('FOO' => 'v1.0.0')

      allow(release)
        .to receive(:read_file)
        .with(described_class::VARIABLES_FILE)
        .and_return(YAML.dump('variables' => { 'BLA' => 'master' }))

      ce, ee = release.distribution_component_versions

      expect(ce).to eq(
        'variables' => {
          'GITLAB_VERSION' => 'v42.0.0',
          'GITLAB_REF_SLUG' => 'v42.0.0',
          'GITLAB_ASSETS_TAG' => 'v42.0.0',
          'FOO' => 'v1.0.0',
          'BLA' => 'master'
        }
      )

      expect(ee).to eq(
        'variables' => {
          'GITLAB_VERSION' => 'v42.0.0-ee',
          'GITLAB_REF_SLUG' => 'v42.0.0-ee',
          'GITLAB_ASSETS_TAG' => 'v42.0.0-ee',
          'FOO' => 'v1.0.0',
          'BLA' => 'master'
        }
      )
    end
  end

  describe '#component_versions' do
    before do
      allow(release)
        .to receive(:read_ee_file)
        .with('Gemfile.lock')
        .and_return(File.read("#{VersionFixture.new.fixture_path}/Gemfile.lock"))

      allow(release)
        .to receive(:read_ee_file)
        .with('GITALY_SERVER_VERSION')
        .and_return('1.0.0')

      allow(release)
        .to receive(:read_ee_file)
        .with('GITLAB_SHELL_VERSION')
        .and_return('2.0.0')

      allow(release)
        .to receive(:read_ee_file)
        .with('GITLAB_ELASTICSEARCH_INDEXER_VERSION')
        .and_return('4.0.0')

      allow(release)
        .to receive(:read_ee_file)
        .with('GITLAB_PAGES_VERSION')
        .and_return('5.0.0')
    end

    it 'returns the raw component versions' do
      expect(release.component_versions).to eq(
        'GITALY_SERVER_VERSION' => 'v1.0.0',
        'GITLAB_SHELL_VERSION' => 'v2.0.0',
        'GITLAB_ELASTICSEARCH_INDEXER_VERSION' => 'v4.0.0',
        'GITLAB_PAGES_VERSION' => 'v5.0.0',
        'MAILROOM_VERSION' => '0.9.1'
      )
    end

    context 'when releasing a version prior to 13.10.0' do
      let(:version) { ReleaseTools::CNGVersion.new('13.9.0') }

      it 'includes the Workhorse version' do
        allow(release)
          .to receive(:read_ee_file)
          .with('GITLAB_WORKHORSE_VERSION')
          .and_return('3.0.0')

        expect(release.component_versions).to eq(
          'GITALY_SERVER_VERSION' => 'v1.0.0',
          'GITLAB_SHELL_VERSION' => 'v2.0.0',
          'GITLAB_WORKHORSE_VERSION' => 'v3.0.0',
          'GITLAB_ELASTICSEARCH_INDEXER_VERSION' => 'v4.0.0',
          'GITLAB_PAGES_VERSION' => 'v5.0.0',
          'MAILROOM_VERSION' => '0.9.1'
        )
      end
    end

    context 'when releasing a version for 13.10.0' do
      let(:version) { ReleaseTools::CNGVersion.new('13.10.0') }

      it 'does not include the Workhorse version' do
        expect(release.component_versions).to eq(
          'GITALY_SERVER_VERSION' => 'v1.0.0',
          'GITLAB_SHELL_VERSION' => 'v2.0.0',
          'GITLAB_ELASTICSEARCH_INDEXER_VERSION' => 'v4.0.0',
          'GITLAB_PAGES_VERSION' => 'v5.0.0',
          'MAILROOM_VERSION' => '0.9.1'
        )
      end
    end
  end

  describe '#add_release_data_for_tags' do
    it 'adds the release data for the tags' do
      ce_tag = double(:tag, name: 'v42.0.0.ce')
      ee_tag = double(:tag, name: 'v42.0.0.ee')
      ubi_tag = double(:tag, name: 'v42.0.0.ubi')

      expect(release)
        .to receive(:add_release_data)
        .with('cng-ce', '42.0.0', ce_tag)

      expect(release)
        .to receive(:add_release_data)
        .with('cng-ee', '42.0.0', ee_tag)

      expect(release)
        .to receive(:add_release_data)
        .with('cng-ee-ubi', '42.0.0', ubi_tag)

      release.add_release_data_for_tags(ce_tag, ee_tag, ubi_tag)
    end
  end

  describe '#add_release_data' do
    it 'records the release data' do
      expect(release.release_metadata)
        .to receive(:add_release)
        .with(name: 'cng', version: '1.2.3', sha: '123abc', ref: 'foo', tag: true)

      release.add_release_data(
        'cng',
        '1.2.3',
        double(:tag, commit: double(:commit, id: '123abc'), name: 'foo')
      )
    end
  end

  describe '#read_ee_file' do
    it 'reads a file from the GitLab EE repository' do
      expect(release)
        .to receive(:read_file)
        .with('README.md', 'gitlab-org/gitlab', '42-0-stable-ee')
        .and_return('foo')

      expect(release.read_ee_file('README.md')).to eq('foo')
    end
  end

  describe '#read_file' do
    it 'reads a file from a branch' do
      expect(release.client)
        .to receive(:file_contents)
        .with('gitlab-org/build/CNG', 'README.md', '42-0-stable')
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

  describe '#version_string' do
    it 'prefixes a major-minor version' do
      expect(release.version_string('1.2.3')).to eq('v1.2.3')
    end

    it 'does not prefix a branch name' do
      expect(release.version_string('master')).to eq('master')
    end

    it 'does not prefix a commit SHA' do
      expect(release.version_string('123abc')).to eq('123abc')
    end
  end

  describe '#project' do
    it 'returns the project' do
      expect(release.project).to eq(ReleaseTools::Project::CNGImage)
    end
  end

  describe '#source_for_target_branch' do
    context 'when a custom commit is specified' do
      it 'returns the commit' do
        release = described_class.new(version, commit: 'foo')

        expect(release.source_for_target_branch).to eq('foo')
      end
    end

    context 'when no custom commit is specified' do
      it 'returns the default branch name' do
        release = described_class.new(version)

        expect(release.source_for_target_branch).to eq('master')
      end
    end
  end
end
