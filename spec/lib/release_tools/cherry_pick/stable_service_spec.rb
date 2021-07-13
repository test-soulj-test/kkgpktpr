# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::CherryPick::StableService do
  let(:version) { ReleaseTools::Version.new('11.4.0-rc8') }
  let(:target) do
    double(
      branch_name: 'branch-name',
      exists?: true,
      project: ReleaseTools::Project::GitlabCe
    )
  end

  subject do
    described_class.new(target.project, version, target)
  end

  describe 'initialize' do
    it 'validates version argument' do
      version = double(valid?: false)

      expect { described_class.new(double, version, target) }
        .to raise_error(RuntimeError, /Invalid version provided/)
    end

    it 'validates target exists' do
      target = double(exists?: false)

      expect { described_class.new(double, version, target) }
        .to raise_error(RuntimeError, /Invalid cherry-pick target provided/)
    end
  end

  describe '#execute', vcr: { cassette_name: 'cherry_pick/with_prep_mr' } do
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
            double(iid: 1, project_id: 13_083, merge_commit_sha: 'success-a').as_null_object,
            double(iid: 2, project_id: 13_083, merge_commit_sha: 'success-b').as_null_object,

            double(iid: 3, project_id: 13_083, merge_commit_sha: 'failure-a').as_null_object,
            double(iid: 4, project_id: 13_083, merge_commit_sha: 'failure-b').as_null_object,
            double(iid: 5, project_id: 13_083, merge_commit_sha: 'failure-c').as_null_object,
          ]
        )
      end

      before do
        allow(subject).to receive(:notifier).and_return(notifier)
        allow(subject).to receive(:client).and_return(internal_client)
        allow(subject).to receive(:pickable_mrs).and_return(picks)
      end

      it 'attempts to cherry pick each merge request' do
        expect(subject)
          .to receive(:cherry_pick_merge_request_commits)
          .exactly(5)
          .times

        # Unset the `TEST` environment so we call the stubbed `cherry_pick`
        without_dry_run do
          subject.execute
        end
      end

      it 'posts a comment to each merge request' do
        stub_picking

        subject.execute

        expect(notifier).to have_received(:comment).exactly(5).times
      end

      it 'posts a summary comment to the preparation MR' do
        stub_picking

        subject.execute

        expect(notifier).to have_received(:summary)
      end

      it 'posts a blog post summary comment' do
        stub_picking

        subject.execute

        expect(notifier).to have_received(:blog_post_summary)
      end
    end
  end

  describe '#cherry_pick_merge_request_commits' do
    let(:mr) do
      double(
        :merge_request,
        iid: 42,
        merge_commit_sha: '123abc',
        web_url: 'https://example.com'
      )
    end

    let(:mr_commit1) { double(:mr_commit1, id: 'abc1', message: 'foo') }
    let(:mr_commit2) { double(:mr_commit2, id: 'abc2', message: 'bar') }

    before do
      allow(ReleaseTools::GitlabClient)
        .to receive(:merge_request_commits)
        .with(target.project, 42)
        .and_return(Gitlab::PaginatedResponse.new([mr_commit1, mr_commit2]))
    end

    context 'when there are no changelog commits' do
      it 'cherry picks the merge request directly' do
        allow(subject)
          .to receive(:changelog_commits)
          .with([mr_commit2, mr_commit1])
          .and_return([])

        expect(ReleaseTools::GitlabClient)
          .to receive(:cherry_pick)
          .with(target.project, ref: '123abc', target: 'branch-name')

        subject.send(:cherry_pick_merge_request_commits, mr)
      end
    end

    context 'when there is a single changelog commits' do
      it 'cherry picks the single changelog commit' do
        changelog_commit = double(:changelog_commit, id: '456abc')

        allow(subject)
          .to receive(:changelog_commits)
          .with([mr_commit2, mr_commit1])
          .and_return([changelog_commit])

        expect(subject)
          .to receive(:cherry_pick_with_single_changelog_commit)
          .with(changelog_commit, mr)

        subject.send(:cherry_pick_merge_request_commits, mr)
      end
    end

    context 'when there are multiple changelog commits' do
      it 'cherry picks all merge request commits' do
        changelog_commit1 = double(:changelog_commit, id: '456abc')
        changelog_commit2 = double(:changelog_commit, id: '457def')

        allow(subject)
          .to receive(:changelog_commits)
          .with([mr_commit2, mr_commit1])
          .and_return([changelog_commit1, changelog_commit2])

        expect(ReleaseTools::GitlabClient)
          .to receive(:cherry_pick)
          .ordered
          .with(
            target.project,
            ref: mr_commit2.id,
            target: 'branch-name',
            message: mr_commit2.message
          )

        expect(ReleaseTools::GitlabClient)
          .to receive(:cherry_pick)
          .ordered
          .with(
            target.project,
            ref: mr_commit1.id,
            target: 'branch-name',
            message: mr_commit1.message
          )

        subject.send(:cherry_pick_merge_request_commits, mr)
      end
    end
  end

  describe '#changelog_commits' do
    it 'returns the commits including Changelog trailers' do
      mr_commits = [double(:commit1, id: 'abc'), double(:commit2, id: 'def')]
      commit1 = double(:commit1, id: 'abc', trailers: {})
      commit2 = double(:commit2, id: 'def', trailers: { 'Changelog' => 'added' })

      allow(ReleaseTools::GitlabClient)
        .to receive(:commits)
        .with(target.project, ref_name: 'abc~1..def', trailers: true)
        .and_return(Gitlab::PaginatedResponse.new([commit1, commit2]))

      expect(subject.send(:changelog_commits, mr_commits)).to eq([commit2])
    end
  end

  describe '#cherry_pick_with_single_changelog_commit' do
    it 'cherry picks the commit while retaining the trailers' do
      commit = double(
        :commit,
        id: '123abc',
        trailers: { 'Changelog' => 'added', 'EE' => 'true' }
      )

      mr = double(
        :merge_request,
        title: 'Merge request title',
        web_url: 'https://example.com',
        merge_commit_sha: '123abc'
      )

      expect(ReleaseTools::GitlabClient)
        .to receive(:cherry_pick)
        .with(
          target.project,
          ref: '123abc',
          target: 'branch-name',
          message: <<~MESSAGE.strip
            Merge request title

            See https://example.com

            Changelog: added
            EE: true
          MESSAGE
        )

      subject.send(:cherry_pick_with_single_changelog_commit, commit, mr)
    end
  end
end
