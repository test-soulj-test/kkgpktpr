# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Security::IssuesResult do
  let(:issue1) do
    double(
      :issue,
      iid: 1,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/issues/1',
      reference: 'gitlab-org/security/gitlab#1',
      pending_reason: 'too few merge requests'
    )
  end

  let(:issue2) do
    double(
      :issue,
      iid: 2,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/issues/2',
      reference: 'gitlab-org/security/gitlab#2',
      pending_reason: 'invalid merge requests status'
    )
  end

  let(:issue3) do
    double(
      :issue,
      iid: 3,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/issues/3',
      reference: 'gitlab-org/security/gitlab#3'
    )
  end

  let(:issue4) do
    double(
      :issue,
      iid: 4,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/issues/4',
      reference: 'gitlab-org/security/gitlab#4'
    )
  end

  let(:issues) { [issue1, issue2, issue3, issue4] }

  describe '#build_attachments' do
    let(:issues_result) do
      described_class.new(
        issues: issues,
        pending: [issue1, issue2],
        ready: [issue3, issue4]
      )
    end

    it 'displays an overview' do
      header = issues_result.build_attachments[0]

      expect(header).to match(
        a_hash_including(
          type: 'header',
          text: {
            type: 'plain_text',
            text: "Security Implementation Issues: 4"
          }
        )
      )

      overview = issues_result.build_attachments[1]

      expect(overview).to match(
        a_hash_including(
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: '*:white_check_mark: Ready: `2`       :warning: Pending: `2`*'
          }
        )
      )
    end

    it 'includes information about pending issues' do
      pending_issues_header = issues_result.build_attachments[3]

      expect(pending_issues_header).to match(
        a_hash_including(
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: "* :warning: Pending security issues: 2*"
          }
        )
      )
    end
  end

  context 'without pending issues' do
    let(:issues_result) do
      described_class.new(
        issues: issues,
        pending: [],
        ready: issues
      )
    end

    it 'return no information for pending issues ' do
      result = issues_result.build_attachments

      expect(result).not_to include(':warning: Pending')
    end
  end
end
