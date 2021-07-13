# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Project::OmnibusGitlab do
  it_behaves_like 'project .remotes'
  it_behaves_like 'project .security_group'
  it_behaves_like 'project .security_path', 'gitlab-org/security/omnibus-gitlab'
  it_behaves_like 'project .to_s'
  it_behaves_like 'project .canonical_or_security_path'

  describe '.path' do
    it { expect(described_class.path).to eq 'gitlab-org/omnibus-gitlab' }
  end

  describe '.dev_path' do
    it { expect(described_class.dev_path).to eq 'gitlab/omnibus-gitlab' }
  end

  describe '.group' do
    it { expect(described_class.group).to eq 'gitlab-org' }
  end

  describe '.dev_group' do
    it { expect(described_class.dev_group).to eq 'gitlab' }
  end

  describe '.metadata_project_name' do
    it { expect(described_class.metadata_project_name).to eq('omnibus-gitlab-ee') }
  end
end
