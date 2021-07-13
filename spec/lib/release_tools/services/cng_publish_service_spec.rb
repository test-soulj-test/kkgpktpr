# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Services::CNGPublishService do
  describe '#execute' do
    context 'when no pipeline exists', vcr: { cassette_name: 'pipelines/cng/no_pipeline' } do
      let(:version) { ReleaseTools::Version.new('83.7.2') }

      it 'raises PipelineNotFoundError' do
        service = described_class.new(version)

        expect { service.execute }
          .to raise_error(described_class::PipelineNotFoundError)
      end
    end

    context 'when one pipeline exists' do
      context 'and there are manual jobs', vcr: { cassette_name: 'pipelines/cng/pending' } do
        let(:version) { ReleaseTools::Version.new('12.6.0-rc32') }

        it 'plays all jobs in a release stage' do
          service = described_class.new(version)

          client = service.send(:client)
          allow(client).to receive(:pipelines).and_call_original
          allow(client).to receive(:pipeline_jobs).and_call_original

          # EE and CE  each have 1 manual job and UBI has 2 manual jobs
          expect(client).to receive(:job_play).exactly(4).times

          without_dry_run do
            expect(service.execute.length).to eq(3)
          end
        end
      end

      context 'and there are no manual jobs', vcr: { cassette_name: 'pipelines/cng/released' } do
        let(:version) { ReleaseTools::Version.new('12.0.0') }

        it 'does not play any job' do
          service = described_class.new(version)

          client = service.send(:client)
          expect(client).not_to receive(:job_play)

          expect(service.execute).to be_empty
        end
      end
    end
  end

  describe '#release_versions' do
    let(:version) { ReleaseTools::Version.new('1.1.1') }

    it 'contains UBI tag' do
      expect(described_class.new(version).release_versions).to eq %w(v1.1.1 v1.1.1-ee v1.1.1-ubi8)
    end
  end
end
