# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Security::IssuesFetcher do
  let(:client) { double(:client) }
  let(:issue_crawler) { double(:issue_crawler) }
  let(:issues_result) { double(:issues_result) }

  let(:issue1) do
    double(
      :issue,
      iid: 1,
      ready_to_be_processed?: true,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/issues/1',
      processed?: false
    )
  end

  let(:issue2) do
    double(
      :issue,
      iid: 2,
      ready_to_be_processed?: true,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/issues/2',
      processed?: false
    )
  end

  let(:issue3) do
    double(
      :issue,
      iid: 3,
      ready_to_be_processed?: false,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/issues/3',
      pending_reason: 'invalid merge requests',
      processed?: false
    )
  end

  let(:issue4) do
    double(
      :issue,
      iid: 4,
      ready_to_be_processed?: true,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/issues/4',
      processed?: true
    )
  end

  let(:issues_fetcher) { described_class.new(client) }

  describe '#execute' do
    context 'with security issues' do
      before do
        allow(ReleaseTools::Security::IssueCrawler)
          .to receive(:new)
          .and_return(issue_crawler)

        allow(issue_crawler)
          .to receive(:upcoming_security_issues_and_merge_requests)
          .and_return([issue1, issue2, issue3, issue4])

        allow(ReleaseTools::Slack::ChatopsNotification)
          .to receive(:security_implementation_issues_processed)
          .and_return(nil)
      end

      it 'communicates the issues status' do
        expect(ReleaseTools::Security::IssuesResult)
          .to receive(:new)
          .with(
            a_hash_including(
              issues: [issue1, issue2, issue3, issue4],
              ready: [issue1, issue2],
              pending: [issue3]
            )
          )

        expect(ReleaseTools::Slack::ChatopsNotification)
          .to receive(:security_implementation_issues_processed)

        issues_fetcher.execute
      end

      it 'returns issues that are ready to be processed' do
        expect(issues_fetcher.execute).to eq([issue1, issue2])
      end

      it 'ignores issues that were processed' do
        expect(issue4).not_to receive(:ready_to_be_processed?)

        issues_fetcher.execute
      end
    end

    context 'without security issues' do
      before do
        allow(ReleaseTools::Security::IssueCrawler)
          .to receive(:new)
          .and_return(issue_crawler)

        allow(issue_crawler)
          .to receive(:upcoming_security_issues_and_merge_requests)
          .and_return([])
      end

      it 'returns an empty array' do
        expect(issues_fetcher.execute).to eq([])
      end
    end
  end
end
