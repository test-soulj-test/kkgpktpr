# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Metrics::ReleasePressure do
  include_context 'metric registry'

  subject(:service) { described_class.new }

  before do
    allow(ReleaseTools::GitlabClient).to receive(:client).and_return(spy)
  end

  def stub_versions
    klass = 'ReleaseTools::Versions'
    versions = %w[42.2.0 42.1.1 42.0.2]

    stub_const(klass, class_double(klass, current: versions, latest: versions))
  end

  def mr_stub(labels: [])
    double('Gitlab::ObjectifiedHash', labels: labels)
  end

  describe '#execute' do
    it 'sets release pressure by version and severity' do
      stub_versions
      gauge = stub_gauge(registry)

      allow(service).to receive(:merge_requests).and_call_original

      # We're not going to verify that every permutation returns results; one
      # should be enough
      allow(service).to receive(:merge_requests)
        .with('Pick into 42.0', 'merged')
        .and_return([
          mr_stub(labels: []),
          mr_stub(labels: ['severity::1']),
          mr_stub(labels: ['severity::1']),
          mr_stub(labels: ['severity::2']),
          mr_stub(labels: ['severity::4'])
        ])

      service.execute

      expect(gauge).to have_received(:set)
        .with(1, labels: hash_including(state: 'merged', version: '42.0', severity: 'none'))
      expect(gauge).to have_received(:set)
        .with(2, labels: hash_including(state: 'merged', version: '42.0', severity: 'severity::1'))
      expect(gauge).to have_received(:set)
        .with(1, labels: hash_including(state: 'merged', version: '42.0', severity: 'severity::2'))
      expect(gauge).to have_received(:set)
        .with(0, labels: hash_including(state: 'merged', version: '42.0', severity: 'severity::3'))
      expect(gauge).to have_received(:set)
        .with(1, labels: hash_including(state: 'merged', version: '42.0', severity: 'severity::4'))

      expect(pushgateway).to have_received(:replace).with(registry)
    end
  end
end
