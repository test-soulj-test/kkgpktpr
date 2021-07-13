# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::AutoDeploy::Tagger::Omnibus do
  let(:fake_client) { spy(project_path: described_class::PROJECT.auto_deploy_path) }

  let(:target_branch) do
    ReleaseTools::AutoDeployBranch.new('12-9-auto-deploy-20200226')
  end

  let(:version_map) do
    {
      'VERSION' => SecureRandom.hex(20),
      'GITALY_SERVER_VERSION' => SecureRandom.hex(20)
    }
  end

  subject(:tagger) { described_class.new(target_branch, version_map) }

  before do
    stub_const('ReleaseTools::GitlabClient', fake_client)
  end

  describe '#tag_name' do
    it 'returns a tag name in the appropriate format' do
      commit = double(id: SecureRandom.hex(20))

      allow(tagger).to receive(:branch_head).and_return(commit)

      expect(ReleaseTools::AutoDeploy::Tag).to receive(:current)
        .and_return('1.2.3')

      expect(tagger.tag_name).to eq(
        "1.2.3+#{version_map['VERSION'][0...11]}.#{commit.id[0...11]}"
      )
    end
  end

  describe '#tag_message' do
    it 'returns a formatted tag message' do
      allow(tagger).to receive(:tag_name).and_return('some_tag')

      expected = <<~MSG.chomp
        Auto-deploy Omnibus some_tag

        VERSION: #{version_map['VERSION']}
        GITALY_SERVER_VERSION: #{version_map['GITALY_SERVER_VERSION']}
      MSG

      expect(tagger.tag_message).to eq(expected)
    end
  end

  describe '#tag!' do
    it 'creates a tag on the project' do
      branch_head = double(
        created_at: Time.new(2019, 7, 2, 10, 14),
        id: SecureRandom.hex(20)
      )

      allow(tagger).to receive(:branch_head).and_return(branch_head)
      allow(tagger).to receive(:tag_name).and_return('tag_name')

      without_dry_run do
        tagger.tag!
      end

      expect(fake_client).to have_received(:create_tag)
        .with(described_class::PROJECT.auto_deploy_path, 'tag_name', branch_head.id, anything)
    end

    it 'adds the version data' do
      branch_head = double(
        created_at: Time.new(2019, 7, 2, 10, 14),
        id: 'foo'
      )

      allow(tagger).to receive(:branch_head).and_return(branch_head)
      allow(tagger).to receive(:tag_name).and_return('12.1.3')

      without_dry_run do
        tagger.tag!
      end

      expect(tagger.release_metadata.releases).not_to be_empty
      expect(tagger.release_metadata.releases['omnibus-gitlab-ee'].ref).to eq('12.1.3')
      expect(tagger.release_metadata.releases['omnibus-gitlab-ee'].tag).to eq(true)
    end
  end
end
