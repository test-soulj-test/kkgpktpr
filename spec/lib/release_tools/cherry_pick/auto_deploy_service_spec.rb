# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::CherryPick::AutoDeployService do
  let(:project) { ReleaseTools::Project::GitlabCe }
  let(:target) { 'branch-name' }

  subject do
    described_class.new(project, target)
  end

  describe '#execute' do
    context 'with no pickable MRs' do
      it 'does nothing' do
        expect(subject).to receive(:pickable_mrs).and_return([])

        expect(subject.execute).to eq([])
      end
    end

    context 'with pickable MRs' do
      def stub_picking
        # If the `merge_commit_sha` contains `failure`, we raise an error to
        # simulate a failed pick; otherwise return true
        allow(internal_client).to receive(:cherry_pick) do |_, keywords|
          if keywords[:ref].start_with?('failure')
            raise gitlab_error(:BadRequest, code: 400)
          else
            true
          end
        end
      end

      let(:notifier) { spy }
      let(:internal_client) { spy }
      let(:picks) do
        Gitlab::PaginatedResponse.new(
          [
            double(iid: 1, project_id: 13_083, merge_commit_sha: 'success-a', labels: %w[severity::1 bug]).as_null_object,
            double(iid: 2, project_id: 13_083, merge_commit_sha: 'success-b', labels: %w[severity::2]).as_null_object,
            double(iid: 3, project_id: 13_083, merge_commit_sha: 'success-c', labels: []).as_null_object,

            double(iid: 4, project_id: 13_083, merge_commit_sha: 'failure-a', labels: %w[priority::3]).as_null_object,
            double(iid: 5, project_id: 13_083, merge_commit_sha: 'failure-b', labels: %w[priority::1 severity::1]).as_null_object,
            double(iid: 6, project_id: 13_083, merge_commit_sha: 'failure-c', labels: []).as_null_object,
          ]
        )
      end

      before do
        allow(subject).to receive(:notifier).and_return(notifier)
        allow(subject).to receive(:client).and_return(internal_client)
        allow(subject).to receive(:pickable_mrs).and_return(picks)
      end

      it 'attempts to cherry pick only severity::1 and severity::2 merge requests' do
        stub_picking

        # Ignore assert_mirrored!
        allow(internal_client).to receive(:commit).and_return(true)

        expect(internal_client).to receive(:cherry_pick)
          .with(project.auto_deploy_path, ref: 'success-a', target: target)
        expect(internal_client).to receive(:cherry_pick)
          .with(project.auto_deploy_path, ref: 'success-b', target: target)
        expect(internal_client).to receive(:cherry_pick)
          .with(project.auto_deploy_path, ref: 'failure-b', target: target)

        without_dry_run do
          results = subject.execute

          success = results.select(&:success?)
          expect(success.size).to be(2)
          expect(success[0].merge_request.iid).to eql(picks[0].iid)
          expect(success[1].merge_request.iid).to eql(picks[1].iid)

          denied = results.select(&:denied?)
          expect(denied.size).to be(3)
          expect(denied.map(&:reason).uniq).to eq(['Missing ~severity::1 or ~severity::2 label'])
          expect(results.count(&:failure?)).to be(4)
        end
      end

      it 'posts a comment to each merge request' do
        stub_picking

        subject.execute

        expect(notifier).to have_received(:comment).exactly(6).times
      end

      it 'verifies merge commits exist on Security' do
        stub_picking

        allow(internal_client).to receive(:commit)
          .and_raise(gitlab_error(:NotFound, code: 404))

        expect { subject.execute }
          .to raise_error(described_class::MirrorError)
      end
    end
  end
end
