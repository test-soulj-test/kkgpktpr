# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::CherryPick::AutoDeployNotifier do
  let(:client) { spy('GitlabClient') }
  let(:branch_name) { '13-2-auto-deploy-20200623' }
  let(:project) { ReleaseTools::Project::GitlabEe }

  let(:merge_request) do
    double(
      iid: 3,
      project_id: 2,
      author: double(username: 'liz.lemon')
    )
  end

  subject(:notifier) do
    described_class.new(branch_name, project)
  end

  before do
    stub_const('ReleaseTools::GitlabClient', client)
  end

  describe '#comment' do
    around do |ex|
      without_dry_run { ex.run }
    end

    context 'with a successful pick' do
      it 'posts a success comment' do
        pick_result = ReleaseTools::CherryPick::Result.new(merge_request, :success)

        expect(notifier).to receive(:successful_comment).and_return('success')
        notifier.comment(pick_result)

        expect(client).to have_received(:create_merge_request_comment).with(
          merge_request.project_id,
          merge_request.iid,
          'success'
        )
      end
    end

    context 'with a denied pick' do
      it 'posts a failure comment with a reason' do
        pick_result = ReleaseTools::CherryPick::Result.new(merge_request, :denied)

        expect(notifier).to receive(:denial_comment).and_return('denied')
        notifier.comment(pick_result)

        expect(client).to have_received(:create_merge_request_comment).with(
          merge_request.project_id,
          merge_request.iid,
          'denied'
        )
      end
    end

    context 'with a failed pick' do
      it 'posts a failure comment' do
        pick_result = ReleaseTools::CherryPick::Result.new(merge_request, :failure)

        expect(notifier).to receive(:failure_comment).and_return('failed')
        notifier.comment(pick_result)

        expect(client).to have_received(:create_merge_request_comment).with(
          merge_request.project_id,
          merge_request.iid,
          'failed'
        )
      end
    end
  end

  describe '#successful_comment' do
    it 'includes a success message and removes the label' do
      message = notifier.successful_comment(double)

      expect(message).to include("Successfully picked into #{notifier.branch_link}")
      expect(message).to include('/unlabel ~"Pick into auto-deploy"')
    end
  end

  describe '#denial_comment' do
    it 'includes a denial message, the reason, and removes the label' do
      result = double(merge_request: merge_request, reason: "Just 'cause")
      message = notifier.denial_comment(result)

      expect(message).to include("@liz.lemon This merge request failed")
      expect(message).to include(notifier.branch_link)
      expect(message).to include("* Just 'cause")
      expect(message).to include('/unlabel ~"Pick into auto-deploy"')
    end
  end

  describe '#failure_comment' do
    it 'includes a failure message and removes the label' do
      result = double(merge_request: merge_request)
      message = notifier.failure_comment(result)

      expect(message).to include("@liz.lemon This merge request failed")
      expect(message).to include(notifier.branch_link)
      expect(message).to include('/unlabel ~"Pick into auto-deploy"')
    end
  end
end
