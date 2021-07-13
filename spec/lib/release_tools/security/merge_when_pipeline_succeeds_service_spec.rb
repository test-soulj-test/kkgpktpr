# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReleaseTools::Security::MergeWhenPipelineSucceedsService do
  let(:client) { spy(:client) }

  let(:merge_request) do
    double(
      :merge_request,
      iid: 123,
      project_id: 1,
      source_branch: 'security-fixes-test-vulnerability',
      web_url: 'https://test.com/security/-/merge_requests/1'
    )
  end

  let(:service) { described_class.new(client, merge_request) }

  describe '#execute' do
    let(:pipeline) do
      double(
        :pipeline,
        id: 1234,
        web_url: 'https://test.com/security/gitlab/-/pipelines/123',
        status: 'running'
      )
    end

    before do
      allow(ReleaseTools::GitlabClient)
        .to receive(:create_merge_request_pipeline)
        .and_return(pipeline)

      allow(client)
        .to receive(:pipelines)
        .and_return([pipeline])

      allow(client)
        .to receive(:accept_merge_request)
    end

    it 'triggers a pipeline' do
      expect(ReleaseTools::GitlabClient)
        .to receive(:create_merge_request_pipeline)
        .with(merge_request.project_id, merge_request.iid)
        .once

      without_dry_run do
        service.execute
      end
    end

    it 'waits for the pipeline to start' do
      expect(service).to receive(:wait_for_mr_pipeline_to_start)

      without_dry_run do
        service.execute
      end
    end

    it 'sets MWPS' do
      options = {
        squash: true,
        merge_when_pipeline_succeeds: true,
        should_remove_source_branch: true
      }

      expect(client)
        .to receive(:accept_merge_request)
        .with(merge_request.project_id, merge_request.iid, options)
        .once

      without_dry_run do
        service.execute
      end
    end

    context 'when the pipeline is not ready' do
      let(:pipeline) do
        double(
          :pipeline,
          id: 1234,
          web_url: 'https://test.com/security/gitlab/-/pipelines/123',
          status: 'created'
        )
      end

      it 'does not set MWPS' do
        expect(client)
          .not_to receive(:accept_merge_request)

        without_dry_run do
          service.execute
        end
      end
    end
  end
end
