# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Qa::ProjectChangeset, vcr: { cassette_name: 'commits-api' } do
  let(:project) { ReleaseTools::Project::GitlabCe }
  let(:from_ref) { 'v10.8.0-rc1' }
  let(:to_ref) { 'v10.8.0-rc2' }

  subject { described_class.new(project: project, from: from_ref, to: to_ref) }

  describe 'validations' do
    let(:from_ref) { 'invalid' }

    it 'raises an argument error for an invalid ref' do
      expect do
        subject
      end.to raise_error(ArgumentError)
    end
  end

  describe '#shas', vcr: { cassette_name: 'repository-api-compare' } do
    it 'has the correct shas' do
      shas = subject.shas

      expect(shas).to be_a(Array)
      expect(shas.size).to eq(3)
      expect(shas).to include('7f7153301ad59d864791cb85d8abd1135962e954')
    end
  end

  describe '#commits', vcr: { cassette_name: 'repository-api-compare' } do
    it 'downloads the list of commits from the API' do
      commits = subject.commits
      shas = commits.map { |c| c['id'] }

      expect(commits).to be_a(Array)
      expect(commits.size).to eq(3)
      expect(shas).to include('7f7153301ad59d864791cb85d8abd1135962e954')
    end
  end

  describe '#merge_requests', vcr: { cassette_name: %w[repository-api-compare merge-requests-api] } do
    it 'downloads the list of Merge Requests' do
      mrs = subject.merge_requests

      expect(mrs).to be_a(Array)
      expect(mrs.size).to eq(2)
      expect(mrs[0].iid).to eq(18_745)
      expect(mrs[1].iid).to eq(18_744)
    end

    it 'retries retrieving of a merge request when this times out' do
      raised = false

      allow(ReleaseTools::GitlabClient).to receive(:merge_request) do
        if raised
          raised = true
          raise Errno::ETIMEDOUT
        else
          double(:merge_request)
        end
      end

      expect(subject.merge_requests.size).to eq(2)
    end
  end
end
