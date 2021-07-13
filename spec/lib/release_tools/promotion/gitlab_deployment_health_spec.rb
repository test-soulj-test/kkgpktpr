# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::GitlabDeploymentHealth do
  let(:fixture) { "gitlab_deployment_health_service_ok.json" }
  let(:response) { JSON.parse(File.read(File.expand_path("../../../fixtures/promql/#{fixture}", __dir__))) }

  subject(:gitlab_deployment_health) { described_class.new }

  before do
    allow(gitlab_deployment_health).to receive(:run_query).and_return(response)
  end

  describe '#services' do
    subject(:services) { gitlab_deployment_health.services }

    it 'return an array of healthy services' do
      expect(services.size).to eq(7)

      fine = services.all?(&:fine?)
      expect(fine).to be_truthy
    end

    context 'when all the services in cny are failing' do
      let(:fixture) { "gitlab_deployment_health_service_cny_failure.json" }

      it 'has problems' do
        failed_services = %w[api git web].map do |type|
          ReleaseTools::Promotion::GitlabDeploymentHealth::Service
            .new(type, 'cny', false)
        end

        expect(services).to include(*failed_services)
      end
    end

    context 'when there is a failure on main-api' do
      let(:fixture) { "gitlab_deployment_health_service_main_failure.json" }

      it 'has problems' do
        expect(services).to include(
          ReleaseTools::Promotion::GitlabDeploymentHealth::Service
            .new('api', 'main', false)
        )
      end
    end
  end
end
