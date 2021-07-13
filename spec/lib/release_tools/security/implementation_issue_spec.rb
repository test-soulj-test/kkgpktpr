# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Security::ImplementationIssue do
  let(:project) do
    double(
      :project,
      iid: 1,
      name: 'GitLab'
    )
  end

  let(:references_response) do
    double(
      'Gitlab::ObjectifiedHash',
      short: 430,
      relative: "#430",
      full: 'gitlab-org/release-tools#430'
    )
  end

  let(:issue_response) do
    double(
      'Gitlab::ObjectifiedHash',
      iid: 430,
      project_id: project.iid,
      web_url: 'https://gitlab.com/gitlab-org/security/gitlab/-/issues/430',
      references: references_response
    )
  end

  let(:release_bot) do
    {
      id: described_class::GITLAB_RELEASE_BOT_ID,
      name: 'GitLab Release Bot'
    }
  end

  let(:mr1) do
    double(
      :merge_request,
      state: described_class::OPENED,
      target_branch: 'master',
      assignees: [release_bot]
    )
  end

  let(:mr2) do
    double(
      :merge_request,
      state: described_class::OPENED,
      target_branch: '12-10-stable-ee',
      assignees: [release_bot]
    )
  end

  let(:mr3) do
    double(
      :merge_request,
      state: described_class::OPENED,
      target_branch: '12-9-stable-ee',
      assignees: [release_bot]
    )
  end

  let(:mr4) do
    double(
      :merge_request,
      state: described_class::OPENED,
      target_branch: '12-8-stable-ee',
      assignees: [release_bot]
    )
  end

  let(:merge_requests) { [mr1, mr2, mr3, mr4] }

  subject { described_class.new(issue_response, merge_requests) }

  describe '#project_id' do
    it { expect(subject.project_id).to eq(issue_response.project_id) }
  end

  describe '#iid' do
    it { expect(subject.iid).to eq(issue_response.iid) }
  end

  describe '#merge_requests' do
    it { expect(subject.merge_requests).to match_array(merge_requests) }
  end

  describe '#web_url' do
    it { expect(subject.web_url).to eq(issue_response.web_url) }
  end

  describe '#reference' do
    it { expect(subject.reference).to eq(issue_response.references.full) }
  end

  describe '#ready_to_be_processed?' do
    let(:validator) { double(:validator) }

    before do
      allow(ReleaseTools::Security::MergeRequestsValidator)
        .to receive(:new)
        .and_return(validator)

      allow(validator)
        .to receive(:execute)
        .and_return([merge_requests, []])
    end

    context 'with 4 or more merge requests associated and all of them assigned to GitLab bot' do
      it { is_expected.to be_ready_to_be_processed }

      it 'does not populate pending_reason' do
        expect(subject.pending_reason).to be_nil
      end
    end

    context 'with less than 4 associated merge requests' do
      let(:merge_requests) { [mr1, mr2] }

      it { is_expected.not_to be_ready_to_be_processed }

      it 'populates pending_reason' do
        subject.ready_to_be_processed?

        expect(subject.pending_reason).to eq('missing merge requests')
      end
    end

    context 'when a merge request is not assigned to the GitLab Release Bot' do
      let(:assignee1) do
        {
          id: 1234,
          name: 'Joe'
        }
      end

      let(:mr4) do
        double(
          :merge_request,
          state: described_class::OPENED,
          target_branch: '12-10-stable-ee',
          assignees: [assignee1]
        )
      end

      it { is_expected.not_to be_ready_to_be_processed }

      it 'populates pending reason' do
        subject.ready_to_be_processed?

        expect(subject.pending_reason).to eq('unassigned merge requests')
      end
    end

    context 'with a merged merge request targeting master' do
      let(:mr1) do
        double(
          :merge_request,
          state: 'merged',
          target_branch: 'master',
          assignees: [release_bot]
        )
      end

      it { is_expected.to be_ready_to_be_processed }
    end

    context 'with merged backports' do
      let(:mr2) do
        double(
          :merge_request,
          state: described_class::MERGED,
          target_branch: '12-10-stable-ee'
        )
      end

      it { is_expected.not_to be_ready_to_be_processed }

      it 'populates pending reason' do
        subject.ready_to_be_processed?

        expect(subject.pending_reason).to eq('invalid merge requests status')
      end
    end

    context 'with valid merge requests' do
      it { is_expected.to be_ready_to_be_processed }
    end

    context 'with invalid merge_requests' do
      before do
        allow(validator)
        .to receive(:execute)
        .and_return([[mr1, mr2, mr3], [mr4]])
      end

      it { is_expected.not_to be_ready_to_be_processed }

      it 'populates pending reason' do
        subject.ready_to_be_processed?

        expect(subject.pending_reason).to eq('invalid merge requests')
      end
    end
  end

  describe '#merge_request_targeting_default_branch' do
    it 'returns the merge request targeting master' do
      expect(subject.merge_request_targeting_default_branch).to eq(mr1)
    end
  end

  describe '#backports' do
    let(:mr5) do
      double(
        :merge_request,
        target_branch: '12-10-stable',
        assignees: [release_bot]
      )
    end

    let(:merge_requests) { [mr1, mr2, mr3, mr5] }

    it 'returns merge requests targeting stable branches' do
      merge_requests_targeting_stable_branches = [
        mr2,
        mr3,
        mr5
      ]

      expect(subject.backports)
        .to match_array(merge_requests_targeting_stable_branches)
    end
  end

  describe '#project_with_auto_deploy?' do
    context 'with a GitLab or Omnibus security issue' do
      it 'returns true for both projects' do
        issue1 = described_class.new(
          double(project_id: described_class::GITLAB_ID).as_null_object, merge_requests
        )

        issue2 = described_class.new(
          double(project_id: described_class::OMNIBUS_ID).as_null_object, merge_requests
        )

        expect(issue1).to be_project_with_auto_deploy
        expect(issue2).to be_project_with_auto_deploy
      end
    end

    context 'with an issue belonging to another project' do
      let(:project) do
        double(
          :project,
          iid: 123,
          name: 'Foo'
        )
      end

      it 'returns false' do
        issue1 = described_class.new(issue_response, merge_requests)

        expect(issue1).not_to be_project_with_auto_deploy
      end
    end
  end

  describe '#processed?' do
    let(:mr1) { double(:merge_request, state: described_class::MERGED) }
    let(:mr2) { double(:merge_request, state: described_class::MERGED) }

    let(:merge_requests) do
      [mr1, mr2]
    end

    context 'with all merge requests merged' do
      it 'returns true' do
        issue1 = described_class.new(double.as_null_object, merge_requests)

        expect(issue1).to be_processed
      end
    end

    context 'with a merge request opened' do
      let(:mr2) do
        double(
          :merge_request,
          state: described_class::OPENED
        )
      end

      it 'returns false' do
        issue1 = described_class.new(double.as_null_object, merge_requests)

        expect(issue1).not_to be_processed
      end
    end
  end

  describe '#allowed_to_early_merge?' do
    let(:mr) do
      double(
        :merge_request,
        target_branch: 'master',
        state: described_class::OPENED,
        project_id: described_class::GITLAB_ID
      )
    end

    subject do
      described_class.new(issue_response, [mr])
    end

    context 'with an MR targeting master' do
      context 'with an opened MR that belongs to GitLab Security' do
        it { is_expected.to be_allowed_to_early_merge }
      end

      context 'when an MR belongs to other project' do
        let(:mr) do
          double(
            :merge_request,
            state: described_class::OPENED,
            target_branch: 'master',
            project_id: described_class::OMNIBUS_ID
          )
        end

        it { is_expected.not_to be_allowed_to_early_merge }
      end

      context 'with a merged MR' do
        let(:mr) do
          double(
            :merge_request,
            target_branch: 'master',
            state: described_class::MERGED,
            project_id: described_class::GITLAB_ID
          )
        end

        it { is_expected.not_to be_allowed_to_early_merge }
      end
    end

    context 'with no MR targeting master' do
      let(:mr) do
        double(
          :merge_request,
          target_branch: '13-3-stable-ee',
          project_id: 123
        )
      end

      it { is_expected.not_to be_allowed_to_early_merge }
    end
  end

  describe '#pending_merge_requests' do
    context 'with a GitLab or Omnibus security issue' do
      it 'returns backports' do
        described_class::PROJECTS_ALLOWED_TO_EARLY_MERGE.each do |project_id|
          issue_response = double(
            project_id: project_id, iid: 1, web_url: '', references: references_response
          )

          issue = described_class.new(issue_response, merge_requests)

          expect(issue.pending_merge_requests).to match_array(issue.backports)
        end
      end
    end

    context 'with another security issue' do
      it 'returns opened merge requests' do
        issue = described_class.new(issue_response, merge_requests)

        expect(issue.pending_merge_requests).to match_array(merge_requests)
      end
    end
  end
end
