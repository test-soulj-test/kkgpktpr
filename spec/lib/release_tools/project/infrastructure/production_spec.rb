# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Project::Infrastructure::Production do
  it_behaves_like 'project .remotes'
  it_behaves_like 'project .to_s'

  describe '.path' do
    it { expect(described_class.path).to eq 'gitlab-com/gl-infra/production' }
  end

  describe '.dev_path' do
    it 'raises an exception' do
      expect { described_class.dev_path }
        .to raise_error("Invalid remote for gitlab-com/gl-infra/production: dev")
    end
  end

  describe '.group' do
    it { expect(described_class.group).to eq 'gitlab-com/gl-infra' }
  end

  describe '.dev_group' do
    it 'raises an exception' do
      expect { described_class.dev_group }
        .to raise_error("Invalid remote for gitlab-com/gl-infra/production: dev")
    end
  end
end
