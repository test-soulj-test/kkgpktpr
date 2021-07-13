# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Project::Deployer do
  it_behaves_like 'project .remotes'
  it_behaves_like 'project .to_s'

  describe '.path' do
    it { expect(described_class.path).to eq 'gitlab-com/gl-infra/deployer' }
  end

  describe '.group' do
    it { expect(described_class.group).to eq 'gitlab-com/gl-infra' }
  end

  describe '.dev_path' do
    it { expect { described_class.dev_path }.to raise_error RuntimeError, 'Invalid remote for gitlab-com/gl-infra/deployer: dev' }
  end

  describe '.dev_group' do
    it { expect { described_class.dev_group }.to raise_error RuntimeError, 'Invalid remote for gitlab-com/gl-infra/deployer: dev' }
  end

  describe '.ops_path' do
    it { expect(described_class.ops_path).to eq 'gitlab-com/gl-infra/deployer' }
  end

  describe '.ops_group' do
    it { expect(described_class.ops_group).to eq 'gitlab-com/gl-infra' }
  end
end
