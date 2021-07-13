# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::SecurityPatchIssue do
  let(:versions) do
    [
      ReleaseTools::Version.new('12.7.4'),
      ReleaseTools::Version.new('12.6.6'),
      ReleaseTools::Version.new('12.5.9')
    ]
  end

  it_behaves_like 'issuable #initialize'

  describe '#title' do
    context 'with a regular security release' do
      it 'includes all the versions' do
        issue = described_class.new(versions: versions)

        expect(issue.title).to eq('Security patch release: 12.7.4, 12.6.6, 12.5.9')
      end
    end

    context 'with a critical security release' do
      it 'includes the critical part' do
        allow(ReleaseTools::SharedStatus)
          .to receive(:critical_security_release?)
          .and_return(true)

        issue = described_class.new(versions: versions)

        expect(issue.title).to eq('Critical security patch release: 12.7.4, 12.6.6, 12.5.9')
      end
    end
  end

  describe '#confidential?' do
    it 'is always confidential' do
      issue = described_class.new(versions: versions)

      expect(issue).to be_confidential
    end
  end

  describe '#labels' do
    it 'includes the "security" label' do
      issue = described_class.new(versions: versions)

      expect(issue.labels).to eq 'Monthly Release,security'
    end
  end

  describe '#description' do
    it 'includes a step to create the blog post in a private snippet' do
      issue = described_class.new(versions: versions)

      content = issue.description

      expect(content).to include 'Link to the blog post on security'
    end

    it 'includes a step to perform a security release' do
      issue = described_class.new(versions: versions)

      content = issue.description

      expect(content).to include '/chatops run release tag --security 12.7.4'
      expect(content).to include '/chatops run release tag --security 12.6.6'
      expect(content).to include '/chatops run release tag --security 12.5.9'
    end

    it 'includes a step to publish the packages' do
      issue = described_class.new(versions: versions)

      content = issue.description

      expect(content).to include '/chatops run publish 12.7.4'
      expect(content).to include '/chatops run publish 12.6.6'
      expect(content).to include '/chatops run publish 12.5.9'
    end

    it 'includes the correct instance for packages' do
      issue = described_class.new(versions: versions)

      content = issue.description

      expect(content).to include 'release.gitlab.net'
    end
  end

  describe '#version' do
    it 'returns the highest version' do
      issue = described_class.new(versions: versions)

      expect(issue.version).to eq('12.7.4')
    end

    context 'with unsorted versions' do
      let(:versions) do
        [
          ReleaseTools::Version.new('12.6.6'),
          ReleaseTools::Version.new('12.7.4'),
          ReleaseTools::Version.new('12.5.9')
        ]
      end

      it 'returns the highest version' do
        issue = described_class.new(versions: versions)

        expect(issue.version).to eq('12.7.4')
      end
    end
  end

  describe '#critical?' do
    context 'with a regular security release' do
      it { is_expected.not_to be_critical }
    end

    context 'with a critical security release' do
      before do
        allow(ReleaseTools::SharedStatus)
          .to receive(:critical_security_release?)
          .and_return(true)
      end

      it { is_expected.to be_critical }
    end
  end

  describe '#regular?' do
    context 'with a regular security release' do
      it { is_expected.to be_regular }
    end

    context 'with a critical security release' do
      before do
        allow(ReleaseTools::SharedStatus)
          .to receive(:critical_security_release?)
          .and_return(true)
      end

      it { is_expected.not_to be_regular }
    end
  end
end
