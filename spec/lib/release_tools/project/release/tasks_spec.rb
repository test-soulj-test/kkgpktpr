# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Project::Release::Tasks do
  it_behaves_like 'project .remotes'
  it_behaves_like 'project .to_s'

  describe '.path' do
    it { expect(described_class.path).to eq 'gitlab-org/release/tasks' }
  end

  describe '.dev_path' do
    it 'raises an exception' do
      expect { described_class.dev_path }
        .to raise_error("Invalid remote for gitlab-org/release/tasks: dev")
    end
  end

  describe '.group' do
    it { expect(described_class.group).to eq 'gitlab-org/release' }
  end

  describe '.dev_group' do
    it 'raises an exception' do
      expect { described_class.dev_group }
        .to raise_error("Invalid remote for gitlab-org/release/tasks: dev")
    end
  end
end
