# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Services::OmnibusPublishService do
  describe '#execute' do
    context 'when no pipeline exists', vcr: { cassette_name: 'pipelines/omnibus/no_pipeline' } do
      let(:version) { ReleaseTools::Version.new('83.7.2') }

      it 'raises PipelineNotFoundError' do
        service = described_class.new(version)

        expect { service.execute }
          .to raise_error(described_class::PipelineNotFoundError)
      end
    end

    context 'when one pipeline exists' do
      # EE: https://dev.gitlab.org/gitlab/omnibus-gitlab/pipelines/96413
      # CE: https://dev.gitlab.org/gitlab/omnibus-gitlab/pipelines/96417
      context 'and there are manual jobs', vcr: { cassette_name: 'pipelines/omnibus/pending' } do
        let(:version) { ReleaseTools::Version.new('11.4.0-rc3') }

        it 'plays all jobs in a release stage' do
          service = described_class.new(version)

          client = service.send(:client)
          allow(client).to receive(:pipelines).and_call_original
          allow(client).to receive(:pipeline_jobs).and_call_original

          # EE and CE each have 17 manual jobs
          expect(client).to receive(:job_play).exactly(17 * 2).times

          without_dry_run do
            expect(service.execute.length).to eq(2)
          end
        end
      end

      # EE: https://dev.gitlab.org/gitlab/omnibus-gitlab/pipelines/86189
      # CE: https://dev.gitlab.org/gitlab/omnibus-gitlab/pipelines/86193
      context 'and there are no manual jobs', vcr: { cassette_name: 'pipelines/omnibus/released' } do
        let(:version) { ReleaseTools::Version.new('11.1.0-rc4') }

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
