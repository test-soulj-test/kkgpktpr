# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Security::MergeRequestsMerger do
  let(:client) { spy(:client) }
  let(:batch_merger) { described_class.new }
  let(:issues_fetcher) { double(:issues_fetcher) }
  let(:cherry_picker) { double(:cherry_picker) }
  let(:mwps_service) { double(:mwps_service) }

  let(:batch_merger_result) do
    double(processed: [], unprocessed: [])
  end

  let(:author) { double(:user, id: 123, username: 'joe') }

  let(:mr1) do
    double(
      :merge_request,
      state: 'opened',
      iid: 1,
      project_id: 1,
      source_branch: 'security-fixes-test-vulnerability',
      target_branch: 'master',
      web_url: 'https://test.com/security/-/merge_requests/1',
      author: author
    )
  end

  let(:mr2) do
    double(
      :merge_request,
      state: 'opened',
      iid: 2,
      project_id: 1,
      target_branch: '12-10-stable-ee',
      web_url: 'https://test.com/security/-/merge_requests/2',
      author: author
    )
  end

  let(:mr3) do
    double(
      :merge_request,
      state: 'opened',
      iid: 3,
      project_id: 1,
      target_branch: '12-9-stable-ee',
      web_url: 'https://test.com/security/-/merge_requests/3',
      author: author
    )
  end

  let(:mr4) do
    double(
      :merge_request,
      state: 'opened',
      iid: 4,
      project_id: 1,
      target_branch: '12-8-stable-ee',
      web_url: 'https://test.com/security/-/merge_requests/4',
      author: author
    )
  end

  let(:merge_requests) { [mr1, mr2, mr3, mr4] }

  let(:issue1) do
    double(
      :issue,
      iid: 1,
      project_id: 1,
      web_url: 'https://test.com/security/-/issues/1',
      merge_requests: merge_requests,
      merge_request_targeting_default_branch: mr1,
      backports: [mr2, mr3, mr4],
      project_with_auto_deploy?: true,
      allowed_to_early_merge?: true
    )
  end

  let(:issues) { [issue1] }

  before do
    stub_const('ReleaseTools::Security::Client', client)

    allow(ReleaseTools::Security::IssuesFetcher)
      .to receive(:new)
      .and_return(issues_fetcher)

    allow(ReleaseTools::Security::BatchMergerResult)
      .to receive(:new)
      .and_return(batch_merger_result)

    allow(ReleaseTools::Security::CherryPicker)
      .to receive(:new)
      .and_return(cherry_picker)

    allow(ReleaseTools::Slack::ChatopsNotification)
      .to receive(:security_merge_requests_processed)
      .and_return(nil)
  end

  describe '#execute' do
    before do
      allow(issues_fetcher)
        .to receive(:execute)
        .and_return(issues)

      allow(batch_merger)
        .to receive(:validated_merge_requests)
        .with(merge_requests)
        .and_return([merge_requests, []])
    end

    context 'when processing MRs targeting default branch' do
      let(:batch_merger) do
        described_class.new(merge_default: true)
      end

      before do
        allow(ReleaseTools::Security::MergeWhenPipelineSucceedsService)
          .to receive(:new)
          .with(client, mr1)
          .and_return(mwps_service)
      end

      it 'only process MR targeting default branch' do
        expect(mwps_service).to receive(:execute)

        expect(ReleaseTools::Slack::ChatopsNotification)
          .to receive(:security_merge_requests_processed)

        without_dry_run do
          batch_merger.execute
        end
      end

      context 'without an MR targeting default branch' do
        let(:issue1) do
          double(
            :issue,
            iid: 1,
            web_url: 'https://test.com/security/-/issues/1',
            merge_requests: merge_requests,
            merge_request_targeting_default_branch: nil,
            backports: [mr2, mr3, mr4],
            project_with_auto_deploy?: false,
            allowed_to_early_merge?: false
          )
        end

        it 'does nothing' do
          expect(mwps_service).not_to receive(:execute)

          expect(ReleaseTools::Slack::ChatopsNotification)
            .to receive(:security_merge_requests_processed)

          without_dry_run do
            batch_merger.execute
          end
        end
      end

      context 'when a security issue is not allowed to early merge' do
        let(:issue1) do
          double(
            :issue,
            iid: 1,
            web_url: 'https://test.com/security/-/issues/1',
            merge_requests: merge_requests,
            merge_request_targeting_default_branch: mr1,
            backports: [mr2, mr3, mr4],
            project_with_auto_deploy?: false,
            allowed_to_early_merge?: false
          )
        end

        it 'does not process MR targeting default branch' do
          expect(mwps_service).not_to receive(:execute)

          expect(ReleaseTools::Slack::ChatopsNotification)
            .to receive(:security_merge_requests_processed)

          without_dry_run do
            batch_merger.execute
          end
        end
      end
    end

    context 'when pending merge requests' do
      let(:issue1) do
        double(
          :issue,
          iid: 1,
          web_url: 'https://test.com/security/-/issues/1',
          merge_requests: merge_requests,
          merge_request_targeting_default_branch: mr1,
          backports: [mr2, mr3, mr4],
          project_with_auto_deploy?: false,
          allowed_to_early_merge?: true,
          pending_merge_requests: [mr2, mr3, mr4]
        )
      end

      before do
        issue1.backports.each do |mr|
          allow(client)
            .to receive(:accept_merge_request)
            .with(mr.project_id, mr.iid, squash: true, should_remove_source_branch: true)
            .and_return(nil)
        end
      end

      it 'processes pending merge requests' do
        issue1.backports.each do |backport|
          expect(client)
            .to receive(:accept_merge_request)
            .with(backport.project_id, backport.iid, squash: true, should_remove_source_branch: true)
        end

        expect(cherry_picker)
          .not_to receive(:execute)

        expect(ReleaseTools::Slack::ChatopsNotification)
          .to receive(:security_merge_requests_processed)

        without_dry_run do
          batch_merger.execute
        end
      end

      context 'with a project with an auto-deploy branch' do
        let(:merged_mr) do
          double(
            :merge_request,
            merge_commit_sha: '1a2b3c',
            target_branch: 'master',
            web_url: 'https://test.com/gitlab/-/merge_requests/1'
          )
        end

        let(:issue1) do
          double(
            :issue,
            iid: 1,
            web_url: 'https://test.com/security/-/issues/1',
            merge_requests: merge_requests,
            merge_request_targeting_default_branch: mr1,
            backports: [mr2, mr3, mr4],
            project_with_auto_deploy?: true,
            allowed_to_early_merge?: true,
            pending_merge_requests: [mr1, mr2, mr3, mr4]
          )
        end

        it 'picks the MR into the auto-deploy branch' do
          allow(client)
            .to receive(:accept_merge_request)
            .with(mr1.project_id, mr1.iid, squash: true, should_remove_source_branch: true)
            .and_return(merged_mr)

          expect(client)
            .to receive(:accept_merge_request)

          expect(cherry_picker)
            .to receive(:execute)

          expect(ReleaseTools::Slack::ChatopsNotification)
            .to receive(:security_merge_requests_processed)

          without_dry_run do
            batch_merger.execute
          end
        end
      end
    end

    context 'when security implementation issues are not ready' do
      it 'does not process the issues' do
        allow(issues_fetcher)
          .to receive(:execute)
          .and_return([])

        expect(batch_merger)
          .not_to receive(:validated_merge_requests)

        expect(batch_merger)
          .not_to receive(:process_merge_requests)

        batch_merger.execute
      end
    end
  end
end
