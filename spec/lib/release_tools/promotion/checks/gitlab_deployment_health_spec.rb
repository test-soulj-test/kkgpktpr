# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::Checks::GitlabDeploymentHealth do
  let(:service1) { ReleaseTools::Promotion::GitlabDeploymentHealth::Service.new('api', 'main', true) }
  let(:service2) { ReleaseTools::Promotion::GitlabDeploymentHealth::Service.new('api', 'cny', true) }
  let(:services) { [service1, service2] }

  subject(:check) { described_class.new }

  before do
    promql_checker = double(services: services)
    allow(ReleaseTools::Promotion::GitlabDeploymentHealth).to receive(:new).and_return(promql_checker)
  end

  context 'when all the services are fine' do
    describe '#fine?' do
      it { is_expected.to be_fine }
    end
  end

  context 'when there are no services' do
    let(:services) { [] }

    describe '#fine?' do
      it { is_expected.not_to be_fine }
    end

    describe '#to_slack_blocks' do
      it 'has a field' do
        elements = check.to_slack_blocks[1][:elements]

        expect(elements).not_to be_empty
        expect(elements[0][:text]).to eq("#{check.failure_icon} no data")
      end
    end
  end

  context 'when a service is not fine' do
    let(:service1) { ReleaseTools::Promotion::GitlabDeploymentHealth::Service.new('api', 'main', false) }

    describe '#fine?' do
      it { is_expected.not_to be_fine }
    end
  end
end
