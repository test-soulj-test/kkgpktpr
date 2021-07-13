# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Security::CloseImplementationIssues do
  let(:client) { double(:client) }
  let(:issue_crawler) { double(:issue_crawler) }
  let(:close_implementation_issues) { described_class.new }

  let(:issue1) do
    double(
      :issue,
      iid: 1,
      project_id: 1,
      processed?: true,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/-/issues/1'
    )
  end

  let(:issue2) do
    double(
      :issue,
      iid: 2,
      project_id: 1,
      processed?: true,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/-/issues/2'
    )
  end

  let(:issue3) do
    double(
      :issue,
      iid: 3,
      project_id: 1,
      processed?: true,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/-/issues/3'
    )
  end

  before do
    allow(ReleaseTools::Security::Client)
      .to receive(:new)
      .and_return(client)

    allow(ReleaseTools::Security::IssueCrawler)
      .to receive(:new)
      .and_return(issue_crawler)
  end

  describe '#execute' do
    context 'with processed implementation issues' do
      it 'closes the issues' do
        allow(issue_crawler)
          .to receive(:upcoming_security_issues_and_merge_requests)
          .and_return([issue1, issue2, issue3])

        expect(client).to receive(:close_issue)
          .exactly(3).times

        without_dry_run do
          close_implementation_issues.execute
        end
      end
    end

    context 'with unprocessed implementation issues' do
      let(:issue3) do
        double(
          :issue,
          iid: 3,
          project_id: 1,
          processed?: false,
          web_url: 'https://gitlab.com/gitlab-org/security/gitlab/-/issues/3'
        )
      end

      it 'only closes issues that are processed' do
        allow(issue_crawler)
          .to receive(:upcoming_security_issues_and_merge_requests)
          .and_return([issue1, issue2, issue3])

        expect(client).to receive(:close_issue)
          .twice

        expect(client).not_to receive(:close_issue)
          .with(1, 3)

        without_dry_run do
          close_implementation_issues.execute
        end
      end
    end

    context 'with no implementation issues' do
      it 'does nothing' do
        allow(issue_crawler)
          .to receive(:upcoming_security_issues_and_merge_requests)
          .and_return([])

        expect(client).not_to receive(:close_issue)

        without_dry_run do
          close_implementation_issues.execute
        end
      end
    end
  end
end
