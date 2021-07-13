# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::ComponentVersions do
  let(:fake_client) { spy }
  let(:target_branch) { '12-9-auto-deploy-20200218' }

  before do
    stub_const('ReleaseTools::GitlabClient', fake_client)
  end

  describe '.for_omnibus' do
    it 'returns a Hash of component versions' do
      commit_id = 'abcdefg'
      file = described_class::FILES.sample

      expect(fake_client).to receive(:file_contents)
        .with(described_class::SOURCE_PROJECT.auto_deploy_path, file, commit_id)
        .and_return("1.2.3\n")

      expect(described_class.for_omnibus(commit_id)).to match(
        a_hash_including(
          'VERSION' => commit_id,
          file => '1.2.3'
        )
      )
    end
  end

  describe '.for_cng' do
    let(:gemfile_fixture) do
      File.read(File.join(VersionFixture.new.fixture_path, 'Gemfile.lock'))
    end

    it 'returns a Hash of component versions' do
      commit_id = 'abcdefg'
      file = described_class::FILES.sample

      expect(fake_client).to receive(:file_contents)
        .with(described_class::SOURCE_PROJECT.auto_deploy_path, file, commit_id)
        .and_return("1.2.3\n")
      expect(fake_client).to receive(:file_contents)
        .with(described_class::SOURCE_PROJECT.auto_deploy_path, 'Gemfile.lock', commit_id)
        .and_return(gemfile_fixture)

      versions = described_class.for_cng(commit_id)

      expect(versions).to match(
        a_hash_including(
          'GITLAB_VERSION' => commit_id,
          file => 'v1.2.3',
          'MAILROOM_VERSION' => '0.9.1'
        )
      )
    end
  end

  describe '.normalize_cng_versions' do
    it 'returns a Hash of component versions' do
      commit_id = 'abcdefg'
      versions = {
        'VERSION' => commit_id,
        'GITALY_SERVER_VERSION' => '1.2.3',
        'SOME_RC_COMPONENT' => '12.9.0-rc5'
      }

      described_class.normalize_cng_versions(versions)

      expect(versions).to match(
        a_hash_including(
          'GITLAB_VERSION' => commit_id,
          'GITLAB_ASSETS_TAG' => commit_id,
          'GITALY_SERVER_VERSION' => 'v1.2.3',
          'SOME_RC_COMPONENT' => 'v12.9.0-rc5'
        )
      )
    end
  end
end
