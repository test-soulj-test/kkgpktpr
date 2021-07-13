# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::AutoDeploy::MinimumCommit do
  describe '#sha' do
    let(:commit) do
      described_class
        .new(ReleaseTools::Project::GitlabEe, '13-11-auto-deploy-2020043012')
    end

    it 'returns the SHA for an auto-deploy branch' do
      tag1 = double(:tag, name: '13.11.202004131215')
      tag2 = double(:tag, name: '13.11.202004131220')

      allow(ReleaseTools::GitlabOpsClient)
        .to receive(:tags)
        .with(
          described_class::TAGS_PROJECT,
          search: '2020043012',
          sort: 'desc',
          order_by: 'name'
        )
        .and_return(Gitlab::PaginatedResponse.new([tag2, tag1]))

      allow(ReleaseTools::GitlabOpsClient)
        .to receive(:release_metadata)
        .with(ReleaseTools::Version.new('13.11.202004131220'))
        .and_return(
          'releases' => {
            'gitlab-ee' => { 'sha' => 'kittens' }
          }
        )

      expect(commit.sha).to eq('kittens')
    end

    it 'returns nil when no tags are found' do
      allow(ReleaseTools::GitlabOpsClient)
        .to receive(:tags)
        .with(
          described_class::TAGS_PROJECT,
          search: '2020043012',
          sort: 'desc',
          order_by: 'name'
        )
        .and_return(Gitlab::PaginatedResponse.new([]))

      expect(commit.sha).to be_nil
    end
  end
end
