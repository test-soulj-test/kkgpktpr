# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::AutoDeploy::Naming do
  subject(:naming) { described_class.new }

  describe '.branch' do
    it 'delegates to described_class#branch' do
      branch = 'X-Y-auto-deploy-YYYYMMDDHH'

      expect(described_class).to receive(:new).and_return(naming)
      expect(naming).to receive(:branch).and_return(branch)

      expect(described_class.branch).to eq(branch)
    end
  end

  describe '#branch' do
    it 'returns a branch name in the appropriate format' do
      expect(naming).to receive(:version).and_return(ReleaseTools::Version.new('4.2')).twice

      Timecop.travel(Time.new(2019, 7, 2, 10)) do
        expect(naming.branch).to eq('4-2-auto-deploy-2019070210')
      end
    end
  end

  describe '#version' do
    it 'delegates to ReleaseTools::ReleaseManagers::Schedule#active_version' do
      version = ReleaseTools::Version.new('13.1')
      schedule = double('schedule', active_version: version)
      expect(ReleaseTools::ReleaseManagers::Schedule).to receive(:new).and_return(schedule)

      expect(naming.version).to eq(version)
    end
  end
end
