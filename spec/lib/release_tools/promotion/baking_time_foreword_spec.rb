# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::BakingTimeForeword do
  let(:deploy_package) { '13.1.202005220540-7c84ccdc806.59f00bb0515' }
  let(:package_version) { ReleaseTools::Version.new(deploy_package) }
  let(:pipeline_url) { 'http://example.com' }

  subject(:foreword) { described_class.new(package_version) }

  around do |ex|
    ClimateControl.modify(CI_PIPELINE_URL: pipeline_url, &ex)
  end

  describe '#to_slack_block' do
    let(:block) { foreword.to_slack_block }

    subject(:message) { block.dig(:text, :text) }

    it 'mentions the release managers' do
      mention = "<!subteam^#{ReleaseTools::Slack::RELEASE_MANAGERS}>"

      expect(message)
        .to include(mention)
    end

    it 'refers to the package version' do
      expect(message)
        .to include(package_version)
    end

    it 'links to the deployer pipeline' do
      expect(message)
        .to include("<#{pipeline_url}|pipeline")
    end

    it 'is a section block' do
      expect(block)
        .to match(
          a_hash_including(type: 'section',
                           text: {
                             type: 'mrkdwn',
                             text: /baking time/
                           })
        )
    end
  end
end
