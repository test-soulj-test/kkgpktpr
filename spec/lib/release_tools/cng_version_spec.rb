# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::CNGVersion do
  def version(version_string)
    described_class.new(version_string)
  end

  describe '#stable_branch' do
    it 'returns separate branch for EE versions before single branch switch' do
      version = version('12.10.10-ee')
      expect(version.stable_branch).to eq('12-10-stable-ee')
    end

    it 'returns same branch for EE versions after single branch switch' do
      cutoff = described_class::CNG_SINGLE_BRANCH_VERSION.dup

      version = version("#{cutoff.to_patch}-rc42").to_ee
      expect(version.stable_branch).not_to include('-ee')
    end
  end
end
