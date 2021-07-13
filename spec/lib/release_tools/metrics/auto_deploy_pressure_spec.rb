# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Metrics::AutoDeployPressure do
  include_context 'metric registry'

  subject(:service) { described_class.new }

  let(:client) do
    stub_const(
      'ReleaseTools::GitlabClient',
      class_spy(
        'ReleaseTools::GitlabClient',
        commits: []
      )
    )
  end

  describe '#execute' do
    def stub_versions(result)
      query_spy = spy(rails_version_by_role: result)

      stub_const('ReleaseTools::Prometheus::Query', query_spy)
    end

    it 'performs one comparison per unique SHA' do
      stub_versions({ 'gstg' => 'aaa', 'gprd-cny' => 'aaa', 'gprd' => 'aaa' })

      expect(client).to receive(:compare).once

      service.execute
    end

    it 'includes the pressure from the previous role in its total' do
      stub_versions({ 'gstg' => 'aaa', 'gprd-cny' => 'bbb', 'gprd' => 'ccc' })
      gauge = stub_gauge(registry)

      expect(service).to receive(:commit_pressure).with('aaa', 'master')
        .and_return(5)
      expect(service).to receive(:commit_pressure).with('bbb', 'aaa')
        .and_return(3)
      expect(service).to receive(:commit_pressure).with('ccc', 'bbb')
        .and_return(1)

      service.execute

      # 5 commits from `master` to `aaa`
      expect(gauge).to have_received(:set)
        .with(5, labels: hash_including(role: 'gstg'))

      # 3 commits from `bbb` to `aaa` + 5 from previous
      expect(gauge).to have_received(:set)
        .with(8, labels: hash_including(role: 'gprd-cny'))

      # 1 commit from `ccc` to `bbb` + 8 from previous
      expect(gauge).to have_received(:set)
        .with(9, labels: hash_including(role: 'gprd'))

      expect(pushgateway).to have_received(:replace).with(registry)
    end

    it "doesn't compare unknown versions" do
      stub_versions({ 'gstg' => '', 'gprd-cny' => '' })

      expect(client).not_to receive(:compare)

      service.execute
    end
  end
end
