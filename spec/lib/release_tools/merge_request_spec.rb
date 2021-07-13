# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::MergeRequest do
  it_behaves_like 'issuable #initialize'
  it_behaves_like 'issuable #create', :create_merge_request
  it_behaves_like 'issuable #accept', :accept_merge_request
  it_behaves_like 'issuable #remote_issuable', :find_merge_request
  it_behaves_like 'issuable #url'

  describe '#source_branch' do
    it 'raises if source_branch is not set' do
      expect { described_class.new.source_branch }.to raise_error(ArgumentError, 'Please set a `source_branch`!')
    end

    it 'can be set' do
      expect(described_class.new(source_branch: 'foo').source_branch).to eq('foo')
    end
  end

  describe '#target_branch' do
    it 'defaults to `master`' do
      expect(described_class.new.target_branch).to eq('master')
    end

    it 'can be set' do
      expect(described_class.new(target_branch: 'foo').target_branch).to eq('foo')
    end
  end

  describe '#to_reference' do
    it 'returns the valid reference string' do
      merge_request = described_class.new
      allow(merge_request).to receive(:iid).and_return(1234)

      expect(merge_request.to_reference).to eq('gitlab-org/gitlab!1234')
    end
  end

  describe '#conflicts' do
    it 'returns nil if no conflicts are given' do
      expect(described_class.new.conflicts).to be_nil
    end

    it 'returns array of conflicts if given' do
      expect(described_class.new(conflicts: %i[a b c]).conflicts).to eq(%i[a b c])
    end
  end

  describe '#conflicts?' do
    it 'returns false if conflicts are nil' do
      expect(described_class.new.conflicts?).to be_falsey
    end

    it 'returns false if conflicts are empty' do
      expect(described_class.new(conflicts: %i[]).conflicts?).to be_falsey
    end

    it 'returns true of conflicts are given' do
      expect(described_class.new(conflicts: %i[a b c]).conflicts?).to be_truthy
    end
  end
end
