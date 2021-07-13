# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Project::HelmGitlab do
  it_behaves_like 'project .auto_deploy_path'
  it_behaves_like 'project .remotes'
  it_behaves_like 'project .to_s'

  describe '.path' do
    it { expect(described_class.path).to eq 'gitlab-org/charts/gitlab' }
  end

  describe '.dev_path' do
    it { expect(described_class.dev_path).to eq 'gitlab/charts/gitlab' }
  end

  describe '.group' do
    it { expect(described_class.group).to eq 'gitlab-org/charts' }
  end

  describe '.dev_group' do
    it { expect(described_class.dev_group).to eq 'gitlab/charts' }
  end
end
