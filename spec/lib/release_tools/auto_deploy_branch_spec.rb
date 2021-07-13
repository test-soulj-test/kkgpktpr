# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::AutoDeployBranch do
  let(:branch) { described_class.new('12-9-auto-deploy-20200226') }

  describe '.current_name' do
    context 'when the AUTO_DEPLOY_BRANCH variable is not set' do
      it 'raises KeyError' do
        ClimateControl.modify(AUTO_DEPLOY_BRANCH: nil) do
          expect { described_class.current_name }.to raise_error(KeyError)
        end
      end
    end

    context 'when the AUTO_DEPLOY_BRANCH variable is set' do
      it 'returns the value of the variable' do
        ClimateControl.modify(AUTO_DEPLOY_BRANCH: 'foo') do
          expect(described_class.current_name).to eq('foo')
        end
      end
    end
  end

  describe '.current' do
    it 'returns an AutoDeployBranch for the current auto-deploy branch' do
      branch_name = '12-9-auto-deploy-20200226'
      branch = ClimateControl.modify(AUTO_DEPLOY_BRANCH: branch_name) do
        described_class.current
      end

      expect(branch.version.to_s).to eq('12.9.0')
      expect(branch.to_s).to eq(branch_name)
    end
  end

  describe '#date' do
    it 'returns the date of the branch' do
      expect(branch.date).to eq('20200226')
    end
  end
end
