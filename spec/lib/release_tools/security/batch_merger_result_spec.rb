# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Security::BatchMergerResult do
  let(:issue1) do
    double(
      :issue,
      iid: 1,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/issues/1',
      reference: 'security/gitlab/issues/1'
    )
  end

  let(:issue2) do
    double(
      :issue,
      iid: 2,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/issues/2',
      reference: 'security/gitlab/issues/2'
    )
  end

  subject(:merge_result) { described_class.new }

  describe '#build_attachments' do
    before do
      merge_result.processed << issue1
      merge_result.unprocessed << issue2
    end

    it 'contains issues that were processed' do
      processed_header = merge_result.build_attachments[1]

      expect(processed_header).to match(
        a_hash_including(
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '*:white_check_mark: Processed:*'
          }
        )
      )

      processed_details = merge_result.build_attachments[2]

      expect(processed_details).to match(
        a_hash_including(
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '• <https://gitlab.com/gitlab-org/security/gitlab/issues/1|security/gitlab/issues/1>'
          }
        )
      )
    end

    it 'contains issues that were not processed' do
      unprocessed_header = merge_result.build_attachments[3]

      expect(unprocessed_header).to match(
        a_hash_including(
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '*:red_circle: Unprocessed:*'
          }
        )
      )

      unprocessed_details = merge_result.build_attachments[4]

      expect(unprocessed_details).to match(
        a_hash_including(
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '• <https://gitlab.com/gitlab-org/security/gitlab/issues/2|security/gitlab/issues/2>'
          }
        )
      )
    end
  end
end
