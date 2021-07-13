# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::GitlabOpsClient do
  describe '.project_path' do
    it 'returns the correct project path' do
      project = double(ops_path: 'foo/bar')

      expect(described_class.project_path(project)).to eq 'foo/bar'
    end
  end

  describe '.release_metadata' do
    context 'when the metadata exists' do
      it 'returns the metadata as a Hash' do
        version = ReleaseTools::Version.new('12.0.0')

        allow(described_class)
          .to receive(:file_contents)
          .with(
            ReleaseTools::ReleaseMetadataUploader::PROJECT,
            'releases/12/12.0.0.json'
          )
          .and_return(JSON.dump({ 'a' => 10 }))

        expect(described_class.release_metadata(version)).to eq({ 'a' => 10 })
      end
    end

    context 'when the metadata does not exist' do
      it 'returns an empty Hash' do
        version = ReleaseTools::Version.new('12.0.0')

        allow(described_class)
          .to receive(:file_contents)
          .with(
            ReleaseTools::ReleaseMetadataUploader::PROJECT,
            'releases/12/12.0.0.json'
          )
          .and_raise(gitlab_error(:NotFound))

        expect(described_class.release_metadata(version)).to eq({})
      end
    end
  end
end
