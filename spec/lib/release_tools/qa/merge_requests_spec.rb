# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Qa::MergeRequests do
  let(:merge_requests) do
    described_class.new(
      projects: [ReleaseTools::Project::GitlabEe],
      from: ReleaseTools::Qa::Ref.new('v12.2.201908180819-2ef9c2518c8.bb4e5052979'),
      to: ReleaseTools::Qa::Ref.new('v12.2.201908190917-64a97230554.c8618753217')
    )
  end

  describe '#to_a' do
    it 'returns a list of merge requests' do
      mr1 = double(:mr1, id: 1)
      mr2 = double(:mr1, id: 2)
      omitter = double(:omitter)

      allow(merge_requests)
        .to receive(:merge_requests)
        .and_return([mr1, mr2])

      allow(ReleaseTools::Qa::IssuableOmitterByLabels)
        .to receive(:new)
        .with([mr1, mr2])
        .and_return(omitter)

      allow(omitter)
        .to receive(:execute)
        .and_return([mr1, mr2])

      expect(merge_requests.to_a).to eq([mr1, mr2])
    end
  end

  describe '#merge_requests' do
    it 'returns a unique list of merge requests' do
      mr1 = double(:mr1, id: 1)
      mr2 = double(:mr1, id: 2)
      changeset = double(:changeset)

      allow(ReleaseTools::Qa::ProjectChangeset)
        .to receive(:new)
        .with(
          project: ReleaseTools::Project::GitlabEe,
          from: '2ef9c2518c8',
          to: '64a97230554'
        )
        .and_return(changeset)

      allow(changeset)
        .to receive(:merge_requests)
        .and_return([mr1, mr1, mr2])

      expect(merge_requests.merge_requests).to eq([mr1, mr2])
    end
  end
end
