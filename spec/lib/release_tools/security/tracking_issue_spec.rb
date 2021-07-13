# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Security::TrackingIssue do
  before do
    allow(ReleaseTools::Versions)
      .to receive(:next_security_versions)
      .and_return(['13.5.4', '13.4.7', '13.3.10'])
  end

  subject { described_class.new }

  describe '#title' do
    subject { described_class.new.title }

    it { is_expected.to eq('Security release: 13.6.x, 13.5.x, 13.4.x') }

    context 'when performing a critical security release' do
      subject do
        ClimateControl.modify(SECURITY: 'critical') do
          described_class.new.title
        end
      end

      it { is_expected.to eq('Critical security release: 13.6.x, 13.5.x, 13.4.x') }
    end
  end

  describe '#confidential?' do
    it { is_expected.to be_confidential }
  end

  describe '#labels' do
    subject { described_class.new.labels }

    it { is_expected.to include('upcoming security release') }
    it { is_expected.to include('security') }

    context 'when performing a critical security release' do
      subject do
        ClimateControl.modify(SECURITY: 'critical') do
          described_class.new.labels
        end
      end

      it { is_expected.to include(described_class::CRITICAL_RELEASE_LABEL) }
    end
  end

  describe '#project' do
    subject { described_class.new.project }

    it { is_expected.to eq(ReleaseTools::Project::GitlabEe) }
  end

  describe '#versions' do
    it 'includes a future version and the last two released versions' do
      expect(subject.versions_title).to eq('13.6.x, 13.5.x, 13.4.x')
    end
  end

  describe '#version' do
    it 'returns the next version' do
      expect(subject.version).to eq('13.7.0')
    end
  end

  describe '#description' do
    it 'returns the tracking issue template' do
      expect(subject.description).not_to be_nil
    end
  end

  describe '#due_date' do
    context 'when the security release is wrapped up on the default date' do
      it 'uses 28th of the next month' do
        allow(Date).to receive(:today).and_return(Date.new(2020, 11, 28))

        expect(subject.due_date).to eq('2020-12-28')
      end
    end

    context 'when the security release is wrapped up the first week of the month' do
      it 'uses 28th of the current month' do
        allow(Date).to receive(:today).and_return(Date.new(2020, 12, 5))

        expect(subject.due_date).to eq('2020-12-28')
      end
    end
  end

  describe '#assignees' do
    it 'returns assignees ids' do
      schedule = instance_spy(ReleaseTools::ReleaseManagers::Schedule)

      allow(ReleaseTools::ReleaseManagers::Schedule)
        .to receive(:new)
        .and_return(schedule)

      expect(schedule)
        .to receive(:active_release_managers)
        .and_return([double('user1', id: 1), double('user2', id: 2)])

      expect(subject.assignees).to eq([1, 2])
    end
  end

  describe '#close_outdated_issues' do
    it 'closes existing and outdated security tracking issues' do
      issue = double(:issue, web_url: 'foo', labels: [])

      expect(ReleaseTools::GitlabClient)
        .to receive(:issues)
        .with(
          subject.project,
          labels: subject.labels,
          per_page: 100,
          state: 'opened',
          confidential: true
        )
        .and_return(Gitlab::PaginatedResponse.new([issue]))

      expect(ReleaseTools::GitlabClient)
        .to receive(:close_issue)
        .with(subject.project, issue)

      without_dry_run { subject.close_outdated_issues }
    end

    it 'leaves issues open when performing a dry-run' do
      issue = double(:issue, web_url: 'foo')

      expect(ReleaseTools::GitlabClient)
        .to receive(:issues)
        .with(
          subject.project,
          labels: subject.labels,
          per_page: 100,
          state: 'opened',
          confidential: true
        )
        .and_return(Gitlab::PaginatedResponse.new([issue]))

      expect(ReleaseTools::GitlabClient).not_to receive(:close_issue)

      subject.close_outdated_issues
    end

    it 'does not close critical security issues when performing a normal security release' do
      issue1 = double(:issue, web_url: 'bar', labels: [])
      issue2 = double(
        :issue,
        web_url: 'foo',
        labels: described_class::CRITICAL_RELEASE_LABEL
      )

      expect(ReleaseTools::GitlabClient)
        .to receive(:issues)
        .with(
          subject.project,
          labels: subject.labels,
          per_page: 100,
          state: 'opened',
          confidential: true
        )
        .and_return(Gitlab::PaginatedResponse.new([issue1, issue2]))

      expect(ReleaseTools::GitlabClient)
        .to receive(:close_issue)
        .with(subject.project, issue1)

      expect(ReleaseTools::GitlabClient)
        .not_to receive(:close_issue)
        .with(subject.project, issue2)

      without_dry_run { subject.close_outdated_issues }
    end

    it 'only closes critical security issues when performing a critical release' do
      issue1 = double(:issue, web_url: 'bar', labels: [])
      issue2 = double(
        :issue,
        web_url: 'foo',
        labels: described_class::CRITICAL_RELEASE_LABEL
      )

      expect(ReleaseTools::GitlabClient)
        .to receive(:issues)
        .with(
          subject.project,
          labels: subject.labels,
          per_page: 100,
          state: 'opened',
          confidential: true
        )
        .and_return(Gitlab::PaginatedResponse.new([issue1, issue2]))

      expect(ReleaseTools::GitlabClient)
        .to receive(:close_issue)
        .with(subject.project, issue2)

      expect(ReleaseTools::GitlabClient)
        .not_to receive(:close_issue)
        .with(subject.project, issue1)

      ClimateControl.modify(SECURITY: 'critical') do
        without_dry_run { subject.close_outdated_issues }
      end
    end
  end
end
