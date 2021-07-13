# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Project::GitlabCe do
  it_behaves_like 'project .remotes'
  it_behaves_like 'project .security_group'
  it_behaves_like 'project .security_path', 'gitlab-org/security/gitlab-foss'
  it_behaves_like 'project .to_s'
  it_behaves_like 'project .canonical_or_security_path'

  describe '.path' do
    it { expect(described_class.path).to eq 'gitlab-org/gitlab-foss' }
  end

  describe '.dev_path' do
    it { expect(described_class.dev_path).to eq 'gitlab/gitlabhq' }
  end

  describe '.group' do
    it { expect(described_class.group).to eq 'gitlab-org' }
  end

  describe '.dev_group' do
    it { expect(described_class.dev_group).to eq 'gitlab' }
  end

  describe '.default_branch' do
    context 'when swith_to_main_branch is enabled' do
      before do
        enable_feature(:switch_to_main_branch)
      end

      it { expect(described_class.default_branch).to eq 'main' }
    end

    it { expect(described_class.default_branch).to eq 'master' }
  end

  describe '.metadata_project_name' do
    it { expect(described_class.metadata_project_name).to eq('gitlab-ce') }
  end
end
