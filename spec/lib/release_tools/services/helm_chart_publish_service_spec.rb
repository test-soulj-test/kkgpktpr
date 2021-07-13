# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Services::HelmChartPublishService do
  describe '#execute' do
    context 'when no pipeline exists', vcr: { cassette_name: 'pipelines/helm_chart/no_pipeline' } do
      let(:version) { ReleaseTools::Version.new('83.7.2') }

      it 'raises PipelineNotFoundError' do
        service = described_class.new(version)

        expect { service.execute }
          .to raise_error(described_class::PipelineNotFoundError)
      end
    end

    context 'when one pipeline exists' do
      context 'and there are manual jobs', vcr: { cassette_name: 'pipelines/helm_chart/pending' } do
        let(:version) { ReleaseTools::Version.new('4.6.0') }

        it 'plays all jobs in a release stage' do
          service = described_class.new(version)

          client = service.send(:client)
          allow(client).to receive(:pipelines).and_call_original
          allow(client).to receive(:pipeline_jobs).and_call_original

          expect(client).to receive(:job_play).once

          without_dry_run do
            expect(service.execute.length).to eq(1)
          end
        end
      end

      # https://dev.gitlab.org/gitlab/charts/gitlab/-/pipelines/175065
      context 'and there are no manual jobs', vcr: { cassette_name: 'pipelines/helm_chart/released' } do
        let(:version) { ReleaseTools::Version.new('4.5.2') }

        it 'does not play any job' do
          service = described_class.new(version)

          client = service.send(:client)
          expect(client).not_to receive(:job_play)

          expect(service.execute).to be_empty
        end
      end
    end
  end
end
