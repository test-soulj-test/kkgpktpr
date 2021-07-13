# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::AutoDeploy::Tagger::Coordinator do
  let(:fake_client) { spy(project_path: described_class::PROJECT.path) }

  subject(:tagger) { described_class.new }

  before do
    stub_const('ReleaseTools::GitlabOpsClient', fake_client)
  end

  describe '#tag!' do
    it 'does nothing if already coordinated' do
      expect(ReleaseTools::AutoDeploy).to receive(:coordinator_pipeline?).and_return(true)

      without_dry_run do
        tagger.tag!
      end

      expect(fake_client).not_to have_received(:create_tag)
    end

    it 'creates a tag in the coordinator project' do
      expect(ReleaseTools::AutoDeploy).to receive(:coordinator_pipeline?).and_return(false)
      allow(ReleaseTools::AutoDeploy::Tag).to receive(:current)
        .and_return('13.7.202012100300')

      without_dry_run do
        tagger.tag!
      end

      expect(fake_client).to have_received(:create_tag).with(
        described_class::PROJECT,
        tagger.tag_name,
        described_class::PROJECT.default_branch,
        tagger.tag_message
      )
    end
  end

  describe '#tag_name' do
    it 'returns a tag name in the appropriate format' do
      expect(ReleaseTools::AutoDeploy::Tag).to receive(:current)
        .and_return('1.2.3')

      expect(tagger.tag_name).to eq('1.2.3')
    end
  end

  describe '#tag_message' do
    it 'returns a formatted tag message' do
      expected = 'Created via https://example.com'

      ClimateControl.modify(CI_JOB_URL: 'https://example.com') do
        expect(tagger.tag_message).to eq(expected)
      end
    end
  end
end
