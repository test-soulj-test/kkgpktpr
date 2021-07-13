# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Services::MergeWhenPipelineSucceedsService do
  let(:merge_request) { ReleaseTools::MergeRequest.new }
  let(:token) { 'a token' }

  subject(:service) { described_class.new(merge_request, token: token) }

  describe '.new' do
    it 'initialize a Gitlab::Client with the given token and endpoint' do
      endpoint = 'https://gitlab.example.com'
      client = class_double('Gitlab::Client').as_stubbed_const
      expect(client)
        .to receive(:new)
        .with(private_token: token, endpoint: endpoint)
        .and_return(double(:client, user: double(:user, id: 2)))

      allow(merge_request).to receive(:author).and_return(double(:user, id: 1))
      described_class.new(merge_request, token: token, endpoint: endpoint)
    end
  end

  describe '#execute' do
    context 'when the merge requests is not approved' do
      it 'approves it, wait for the pipeline to start, and accept the merge request' do
        expect(service).to receive(:validate!)
        expect(service).to receive(:approved?).and_return(false)
        expect(service).to receive(:approve)
        expect(service).to receive(:wait_for_mr_pipeline_to_start)
        expect(service).to receive(:merge_when_pipeline_succeeds)

        without_dry_run do
          service.execute
        end
      end
    end

    context 'when the merge requests is approved' do
      it 'waits for the pipeline to start, and accept the merge request' do
        expect(service).to receive(:validate!)
        expect(service).to receive(:approved?).and_return(true)
        expect(service).not_to receive(:approve)
        expect(service).to receive(:wait_for_mr_pipeline_to_start)
        expect(service).to receive(:merge_when_pipeline_succeeds)

        without_dry_run do
          service.execute
        end
      end
    end

    context 'when the pipeline is not ready' do
      it 'does not retry' do
        expect(service).to receive(:validate!)
        expect(service).to receive(:approved?).and_return(false)
        expect(service).to receive(:approve)
        expect(service).to receive(:wait_for_mr_pipeline_to_start).and_raise(described_class::PipelineNotReadyError)
        expect(service).not_to receive(:merge_when_pipeline_succeeds)

        without_dry_run do
          expect { service.execute }.to raise_error(described_class::PipelineNotReadyError)
        end
      end
    end

    context 'when we have a connection problem' do
      it 'does retry' do
        # first run
        expect(service).to receive(:validate!)
        expect(service).to receive(:approved?).and_return(false)
        expect(service).to receive(:approve).and_raise(gitlab_error(:BadRequest))

        # second run
        expect(service).to receive(:validate!)
        expect(service).to receive(:approved?).and_return(false)
        expect(service).to receive(:approve)
        expect(service).to receive(:wait_for_mr_pipeline_to_start)
        expect(service).to receive(:merge_when_pipeline_succeeds)

        without_dry_run do
          service.execute
        end
      end
    end
  end

  describe '#validate!' do
    context 'when the merge request does not exists' do
      it 'raises an error' do
        allow(merge_request).to receive(:remote_issuable).and_return(nil)
        expect(merge_request).to receive(:author).and_call_original

        expect do
          service.validate!
        end.to raise_error(described_class::InvalidMergeRequestError)
      end
    end

    context 'when the provided token belongs to the merge request author' do
      it 'raises an error' do
        author = double(:user, id: 1)
        expect(merge_request).to receive(:author).and_return(author)

        client = instance_double(Gitlab::Client)
        expect(Gitlab::Client).to receive(:new).and_return(client)

        expect(client).to receive(:user).and_return(author)

        expect do
          service.validate!
        end.to raise_error(described_class::SelfApprovalError)
      end
    end
  end

  describe '#approved?' do
    it 'delegates to Gitlab::Client#merge_request_approvals' do
      allow(merge_request).to receive(:iid).and_return(double(:iid))
      allow(merge_request).to receive(:project_id).and_return(double(:project_id))
      approvals = double(:approvals, approved: double(:approved))

      expect(service.client)
        .to receive(:merge_request_approvals)
        .with(merge_request.project_id, merge_request.iid)
        .and_return(approvals)

      expect(service.approved?).to eq(approvals.approved)
    end
  end

  describe '#approve' do
    it 'delegates to Gitlab::Client#approve_merge_request' do
      allow(merge_request).to receive(:iid).and_return(double(:iid))
      allow(merge_request).to receive(:project_id).and_return(double(:project_id))
      allow(merge_request).to receive(:url).and_return(double(:url))

      expect(service.client)
        .to receive(:approve_merge_request)
        .with(merge_request.project_id, merge_request.iid)

      without_dry_run do
        service.approve
      end
    end
  end

  describe '#merge_when_pipeline_succeeds' do
    it 'delegates to Gitlab::Client#accept_merge_request' do
      allow(merge_request).to receive(:iid).and_return(double(:iid))
      allow(merge_request).to receive(:project_id).and_return(double(:project_id))

      expect(service.client)
        .to receive(:accept_merge_request)
        .with(
          merge_request.project_id,
          merge_request.iid,
          merge_when_pipeline_succeeds: true,
          should_remove_source_branch: true
        )

      without_dry_run do
        service.merge_when_pipeline_succeeds
      end
    end
  end
end
