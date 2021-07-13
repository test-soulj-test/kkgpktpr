# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PatchIssue do
  it_behaves_like 'issuable #initialize'

  describe '#title' do
    it 'returns the issue title' do
      issue = described_class.new(version: ReleaseTools::Version.new('8.3.1'))

      expect(issue.title).to eq 'Release 8.3.1'
    end
  end

  describe '#description' do
    it 'includes the stable branch names' do
      issue = described_class.new(version: ReleaseTools::Version.new('8.3.1'))

      content = issue.description

      aggregate_failures do
        expect(content).to include '8-3-stable-ee'
        expect(content).to include("Tag `8.3.1`")
      end
    end

    it 'includes the full version' do
      issue = described_class.new(version: ReleaseTools::Version.new('8.3.1'))

      content = issue.description

      expect(content).to include '8.3.1'
    end
  end

  describe '#labels' do
    it 'returns a list of labels' do
      issue = described_class.new(version: ReleaseTools::Version.new(''))

      expect(issue.labels).to eq 'Monthly Release'
    end
  end

  describe '#monthly_issue' do
    it 'finds an associated monthly issue' do
      issue = described_class.new(version: ReleaseTools::Version.new('11.7.0-rc4'))

      monthly = issue.monthly_issue

      VCR.use_cassette('issues/release-11-7') do
        expect(monthly.iid).to eq(617)
      end
    end
  end

  describe '#link!' do
    context 'on a monthly version' do
      it 'does nothing' do
        issue = described_class.new(version: ReleaseTools::Version.new('11.7.0'))

        expect(ReleaseTools::GitlabClient).not_to receive(:link_issues)

        issue.link!
      end
    end

    context 'on a patch version' do
      it 'links to its monthly issue' do
        issue = described_class.new(version: ReleaseTools::Version.new('11.7.0-rc4'))

        allow(issue).to receive(:monthly_issue).and_return('monthly')
        expect(ReleaseTools::GitlabClient).to receive(:link_issues).with(issue, 'monthly')

        issue.link!
      end
    end
  end

  describe '#assignees' do
    it 'returns the assignee IDs' do
      issue = described_class.new(version: ReleaseTools::Version.new('11.8.2'))
      schedule = instance_spy(ReleaseTools::ReleaseManagers::Schedule)

      allow(ReleaseTools::ReleaseManagers::Schedule)
        .to receive(:new)
        .and_return(schedule)

      expect(schedule)
        .to receive(:active_release_managers)
        .and_return([double('user1', id: 1), double('user2', id: 2)])

      expect(issue.assignees).to eq([1, 2])
    end
  end
end
