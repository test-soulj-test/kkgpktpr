# frozen_string_literal: true

RSpec.shared_context 'metric registry' do
  let(:pushgateway) { spy('Prometheus::Client::Push') }
  let(:registry) { spy('Prometheus::Client::Registry') }

  before do
    stub_const('Prometheus::Client::Push', pushgateway)
    stub_const('Prometheus::Client::Registry', registry)
  end

  # Return a specified mock when `registry.gauge` is called
  def stub_gauge(registry, instance = spy('Prometheus::Client::Gauge'))
    allow(registry).to receive(:gauge).and_return(instance)

    instance
  end
end
