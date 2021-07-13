# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReleaseTools::AutoDeploy do
  describe '.coordinator_pipeline?' do
    context 'with `auto_deploy_coordinator` enabled' do
      before do
        enable_feature(:auto_deploy_coordinator)
      end

      it 'returns true with a tagged pipeline' do
        ClimateControl.modify(CI_COMMIT_TAG: 'v1.2.3') do
          expect(described_class.coordinator_pipeline?).to eq(true)
        end
      end

      it 'returns false without a tagged pipeline' do
        ClimateControl.modify(CI_COMMIT_TAG: nil) do
          expect(described_class.coordinator_pipeline?).to eq(false)
        end
      end

      it 'returns true with a AUTO_DEPLOY_TAG variable' do
        ClimateControl.modify(AUTO_DEPLOY_TAG: 'v1.2.3') do
          expect(described_class.coordinator_pipeline?).to eq(true)
        end
      end
    end

    context 'with `auto_deploy_coordinator` disabled' do
      before do
        disable_feature(:auto_deploy_coordinator)
      end

      it 'returns true' do
        expect(described_class.coordinator_pipeline?).to eq(true)
      end
    end
  end
end
