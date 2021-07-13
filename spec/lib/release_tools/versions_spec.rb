# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReleaseTools::Versions do
  describe '.current' do
    it 'returns versions from version.gitlab.com', vcr: { cassette_name: 'versions/list' } do
      expect(described_class.current).to include('11.7.5', '11.6.9', '11.5.10')
    end
  end

  describe '.next' do
    it 'returns an Array of the next patch versions' do
      versions = %w[1.0.0 1.1.0 1.1.1 1.2.3]

      expect(described_class.next(versions)).to eq(%w[1.0.1 1.1.1 1.1.2 1.2.4])
    end
  end

  describe '.latest' do
    it 'returns the latest versions grouped by minor version' do
      versions = %w[1.0.0 1.1.0 1.1.1 1.2.3]

      expect(described_class.latest(versions, 2)).to eq(%w[1.2.3 1.1.1])
    end
  end

  describe '.next_security_versions' do
    it 'returns the next patch versions of the latest releases', vcr: { cassette_name: 'versions/list' } do
      expect(described_class.next_security_versions)
        .to contain_exactly('11.7.6', '11.6.10', '11.5.11')
    end
  end

  describe '.last_version_for_major' do
    it 'returns the last version for a major version', vcr: { cassette_name: 'versions/list' } do
      expect(described_class.last_version_for_major(11)).to eq('11.7.5')
    end
  end
end
