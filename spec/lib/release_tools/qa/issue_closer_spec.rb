# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Qa::IssueCloser do
  let(:closer) { described_class.new }

  describe '#execute' do
    let(:issue) { double(:issue) }

    before do
      allow(closer)
        .to receive(:qa_issues)
        .and_return([issue])
    end

    it 'closes QA issues that have expired' do
      allow(closer)
        .to receive(:close_issue?)
        .with(issue)
        .and_return(false)

      allow(closer).to receive(:close_issue)

      closer.execute

      expect(closer).not_to have_received(:close_issue)
    end

    it 'does not close QA issues that have not yet expired' do
      allow(closer)
        .to receive(:close_issue?)
        .with(issue)
        .and_return(true)

      allow(closer)
        .to receive(:close_issue)
        .with(issue)

      closer.execute

      expect(closer).to have_received(:close_issue)
    end
  end

  describe '#close_issue?' do
    context 'when the issue does not have a deadline' do
      it 'returns false' do
        issue = double(:issue, description: 'I like turtles')

        expect(closer.close_issue?(issue)).to eq(false)
      end
    end

    context 'when the issue deadline has not yet expired' do
      it 'returns false' do
        # It's a bit unlikely these tests will still run in the year 2500, and
        # this saves us some additional stubbing.
        issue = double(
          :issue,
          description: 'should be completed by **2500-02-13 13:53 UTC**.'
        )

        expect(closer.close_issue?(issue)).to eq(false)
      end
    end

    context 'when the issue deadline has expired' do
      it 'returns true' do
        issue = double(
          :issue,
          description: 'should be completed by **2010-02-13 13:53 UTC**.'
        )

        expect(closer.close_issue?(issue)).to eq(true)
      end
    end
  end

  describe '#close_issue' do
    it 'closes the issue' do
      issue = double(:issue, project_id: 1, iid: 2)

      allow(ReleaseTools::GitlabClient)
        .to receive(:create_issue_note)
        .with(
          ReleaseTools::Project::Release::Tasks,
          issue: issue,
          body: described_class::CLOSING_NOTE
        )

      allow(ReleaseTools::GitlabClient)
        .to receive(:close_issue)
        .with(ReleaseTools::Project::Release::Tasks, issue)

      closer.close_issue(issue)

      expect(ReleaseTools::GitlabClient).to have_received(:create_issue_note)
      expect(ReleaseTools::GitlabClient).to have_received(:close_issue)
    end
  end

  describe '#deadline_for' do
    context 'when there is no deadline' do
      it 'returns nil' do
        issue = double(:issue, description: 'I like turtles')

        expect(closer.deadline_for(issue)).to be_nil
      end
    end

    context 'when there is a valid deadline' do
      it 'returns a Time' do
        issue = double(
          :issue,
          description: 'should be completed by **2500-02-13 13:53 UTC**.'
        )

        expect(closer.deadline_for(issue))
          .to eq(Time.new(2500, 2, 13, 13, 53).utc)
      end
    end

    context 'when there is an invalid deadline' do
      it 'raises an error' do
        issue = double(:issue, description: 'should be completed by **wat**.')

        expect { closer.deadline_for(issue) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#deadline_expired?' do
    context 'when the deadline has expired' do
      it 'returns true' do
        expect(closer.deadline_expired?(Time.new(2010).utc)).to eq(true)
      end
    end

    context 'when the deadline has not expired' do
      it 'returns false' do
        expect(closer.deadline_expired?(Time.new(2500).utc)).to eq(false)
      end
    end
  end

  describe '#qa_issues' do
    it 'returns all opened QA issues' do
      issue = double(:issue)

      allow(ReleaseTools::GitlabClient)
        .to receive(:issues)
        .with(
          ReleaseTools::Project::Release::Tasks,
          labels: 'QA task',
          state: 'opened'
        )
        .and_return([issue])

      expect(closer.qa_issues).to eq([issue])

      expect(ReleaseTools::GitlabClient)
        .to have_received(:issues)
    end
  end
end
