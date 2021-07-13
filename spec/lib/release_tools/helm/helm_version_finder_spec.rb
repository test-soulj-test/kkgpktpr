# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Helm::HelmVersionFinder do
  let(:client) { class_spy(ReleaseTools::GitlabClient) }
  let(:finder) { described_class.new(client) }

  describe '#execute' do
    let(:tags) do
      {
        'v4.0.0' => [12, 0, 0],
        'v4.0.1' => [12, 0, 1],
        'v5.1.0' => [13, 0, 0]
      }
    end

    before do
      allow(finder).to receive(:release_tags).and_return(tags)
    end

    # In the tests below we check explicitly if the return type is a Version.
    # This way we don't end up returning a String by accident, breaking code
    # that expects a Version object.
    #
    # The eq() tests are not enough for this, as a Version is considered equal
    # to a String with the same content.

    context 'when a Helm tag exists for the exact GitLab version' do
      it 'returns the existing Helm version' do
        version = finder.execute(ReleaseTools::Version.new('12.0.0'))

        expect(version).to eq(ReleaseTools::Version.new('4.0.0'))
        expect(version).to be_instance_of(ReleaseTools::Version)
      end
    end

    context 'when a Helm tag exists for the MAJOR.MINOR part of a version' do
      it 'returns the next patch version' do
        version = finder.execute(ReleaseTools::Version.new('12.0.2'))

        expect(version).to be_instance_of(ReleaseTools::Version)
        expect(version).to eq(ReleaseTools::Version.new('4.0.2'))
      end
    end

    context 'when a Helm tag exists for the MAJOR part of a version' do
      it 'returns the next patch version' do
        version = finder.execute(ReleaseTools::Version.new('13.1.0'))

        expect(version).to be_instance_of(ReleaseTools::Version)
        expect(version).to eq(ReleaseTools::Version.new('5.2.0'))
      end
    end

    context 'when no tags exist for the version' do
      it 'returns the next major version' do
        version = finder.execute(ReleaseTools::Version.new('15.0.0'))

        expect(version).to be_instance_of(ReleaseTools::Version)
        expect(version).to eq(ReleaseTools::Version.new('6.0.0'))
      end
    end

    context 'when no tags exist at all' do
      let(:tags) { {} }

      it 'raises RuntimeError' do
        expect { finder.execute(ReleaseTools::Version.new('15.0.0')) }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#matching_tags' do
    let(:tags) do
      {
        'v4.0.0' => [12, 0, 0],
        'v4.0.1' => [12, 0, 1],
        'v4.1.0' => [12, 1, 0]
      }
    end

    it 'returns matching tags for a matching MAJOR.MINOR.PATCH version' do
      expect(finder.matching_tags(tags, 12, 0, 0)).to eq(%w[v4.0.0])
    end

    it 'returns matching tags for a matching MAJOR.MINOR version' do
      expect(finder.matching_tags(tags, 12, 0)).to eq(%w[v4.0.0 v4.0.1])
    end

    it 'returns matching tags for a matching MAJOR version' do
      expect(finder.matching_tags(tags, 12)).to eq(%w[v4.0.0 v4.0.1 v4.1.0])
    end

    it 'returns an empty Array when no matching tags were found' do
      expect(finder.matching_tags(tags, 12, 2, 0)).to be_empty
      expect(finder.matching_tags(tags, 12, 2)).to be_empty
      expect(finder.matching_tags(tags, 13)).to be_empty
    end
  end

  describe '#release_tags' do
    it 'returns the tags and their GitLab versions' do
      tag1 = double(:tag, name: 'v1.0.0', message: 'contains GitLab EE 12.0.0')
      tag2 = double(:tag, name: 'v1.1.0', message: 'contains GitLab EE 12.0.1')
      tag3 = double(:tag, name: 'v1.1.1', message: 'contains GitLab EE 12.0.2')
      page = Gitlab::PaginatedResponse.new([tag1, tag2, tag3])

      allow(client)
        .to receive(:tags)
        .with(ReleaseTools::Project::HelmGitlab, search: '^v', per_page: 100)
        .and_return(page)

      expect(finder.release_tags).to eq(
        'v1.0.0' => [12, 0, 0],
        'v1.1.0' => [12, 0, 1],
        'v1.1.1' => [12, 0, 2]
      )
    end
  end

  describe '#latest_version' do
    it 'returns the latest version from a list of versions' do
      versions = %w[v10.0.0 v1.0.0 v5.0.0]
      latest = finder.latest_version(versions)

      expect(latest).to eq(ReleaseTools::Version.new('10.0.0'))
    end
  end
end
