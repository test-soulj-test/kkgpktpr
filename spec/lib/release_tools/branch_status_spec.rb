# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::BranchStatus do
  let(:versions) { %w[1.1.0 1.2.1 1.3.4] }

  describe '.for_security_release' do
    it 'supplies the latest security versions' do
      mapped = versions.map { |v| ReleaseTools::Version.new(v) }

      expect(ReleaseTools::Versions).to receive(:next_security_versions)
        .and_return(versions)
      expect(described_class).to receive(:for).with(mapped)

      described_class.for_security_release
    end
  end

  describe '.for' do
    it 'returns a `project => status` Hash' do
      allow(described_class).to receive(:project_pipeline).and_return(true)

      results = described_class.for(versions)

      expect(results.keys).to eq(described_class::PROJECTS)
      expect(results.values.count).to eq(versions.count)
      expect(results.values.flatten.count).to eq(described_class::PROJECTS.count * versions.count)
    end
  end
end
