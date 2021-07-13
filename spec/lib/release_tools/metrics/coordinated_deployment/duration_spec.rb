# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Metrics::CoordinatedDeployment::Duration do
  let(:start_time) { '2021-06-14 01:00:00.0000 UTC' }
  let(:client) { double(ReleaseTools::Metrics::Client) }

  subject(:deployment_duration) do
    described_class.new(
      deploy_version: 'abc',
      start_time: start_time
    )
  end

  before do
    allow(ReleaseTools::Metrics::Client).to receive(:new).and_return(client)
  end

  describe '#execute' do
    context 'with measure_deployment_duration enabled' do
      before do
        enable_feature(:measure_deployment_duration)
      end

      it 'records deployment duration' do
        end_time = Time.parse('2021-06-14 03:00:00.0000 UTC')
        duration = end_time - Time.parse(start_time)

        labels = 'coordinator_pipeline,success'

        expect(client).to receive(:observe)
                            .with('deployment_duration_seconds', duration, labels: labels)

        Timecop.freeze(end_time) do
          deployment_duration.execute
        end
      end

      context 'with a nil start_time' do
        let(:start_time) { nil }

        it 'does nothing' do
          expect(client).not_to receive(:observe)

          deployment_duration.execute
        end
      end
    end

    context 'with measure_deployment_duration disabled' do
      it 'does nothing' do
        expect(client).not_to receive(:observe)

        deployment_duration.execute
      end
    end
  end
end
