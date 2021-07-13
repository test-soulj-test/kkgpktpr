# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::VersionClient do
  it 'returns an Array of version entries', vcr: { cassette_name: 'versions/list' } do
    versions = described_class.versions

    expect(versions.length).to eq(50)
    expect(versions.first.version).to eq('11.7.5')
  end
end
