# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Branch do
  let(:branch) { described_class.new(name: 'release-tools-create-branch', project: ReleaseTools::Project::GitlabCe) }

  describe 'create', vcr: { cassette_name: 'branches/create' } do
    it 'creates a new branch in the given project' do
      without_dry_run do
        expect(branch.create(ref: '9-4-stable')).to be_truthy
      end
    end

    it 'points the branch to the correct ref' do
      without_dry_run do
        response = branch.create(ref: '9-4-stable')

        expect(response.commit.short_id).to eq 'b125d211'
      end
    end
  end
end
