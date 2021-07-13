# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::Checks::ActiveDeployments do
  subject(:check) { described_class.new }

  before do
    allow(::ReleaseTools::Chef::Client)
      .to receive(:new)
      .and_return(chef_client)
  end

  context 'when the environment is disabled' do
    let(:chef_client) do
      instance_double(
        'chef_client',
        pipeline_url: 'https://example.com/some/pipeline/url',
        environment_enabled?: false
      )
    end

    describe '#to_slack_blocks' do
      it 'shows check blocks' do
        slack_blocks = check.to_slack_blocks
        expect(slack_blocks.length).to eq(1)
        expect(slack_blocks.first.dig(:text, :text)).to eq(
          ":red_circle: *production deployments*\n" \
          "Production environment locked: There's an active production deployment, " \
          "see the <https://example.com/some/pipeline/url|deployer pipeline>\n"
        )
      end
    end

    describe '#to_issue_body' do
      it 'generates text for an issue' do
        issue_body = check.to_issue_body
        expect(issue_body).to eq(
          ":red_circle: active deployment\n\n" \
          "Production environment locked: There's an active production deployment, see the [deployer pipeline](https://example.com/some/pipeline/url)\n"
        )
      end
    end
  end

  context 'when the environment is enabled' do
    let(:chef_client) do
      instance_double(
        'chef_client',
        pipeline_url: 'https://example.com/some/pipeline/url',
        environment_enabled?: true
      )
    end

    describe '#to_slack_blocks' do
      it 'shows check blocks' do
        slack_blocks = check.to_slack_blocks
        expect(slack_blocks.length).to eq(1)
        expect(slack_blocks.first.dig(:text, :text)).to eq(
          ":white_check_mark: *production deployments*\n"
        )
      end
    end

    describe '#to_issue_body' do
      it 'generates text for an issue' do
        issue_body = check.to_issue_body
        expect(issue_body).to eq(
          ":white_check_mark: no active deployment\n\n"
        )
      end
    end
  end
end
