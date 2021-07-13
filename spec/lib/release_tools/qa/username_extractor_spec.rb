# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Qa::UsernameExtractor do
  let(:team_author_username) { "team_author" }
  let(:team_author_tag) { "@#{team_author_username}" }
  let(:team_mr) do
    double(
      "title" => "Resolve \"Import/Export (import) is broken due to the addition of a CI table\"",
      "author" => double("username" => team_author_username),
      "assignee" => double("username" => "DouweM"),
      "labels" => ["Platform"],
      "sha" => "4f04aeec80bbfcb025e321693e6ca99b01244bb4",
      "merge_commit_sha" => "0065c449ff95cf6e0643bab17ed236c23207b537",
      "web_url" => "https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/18745",
      "merged_by" => double("username" => "DouweM")
    )
  end

  let(:community_merger_username) { "community_merger" }
  let(:community_merger_tag) { "@#{community_merger_username}" }
  let(:community_contribution) do
    double(
      "title" => "Community Contribution",
      "author" => double("username" => "jameslopez"),
      "assignee" => double("username" => "DouweM"),
      "labels" => [described_class::COMMUNITY_CONTRIBUTION_LABEL],
      "sha" => "4f04aeec80bbfcb025e321693e6ca99b01244bb4",
      "merge_commit_sha" => "0065c449ff95cf6e0643bab17ed236c23207b537",
      "web_url" => "https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/18745",
      "merged_by" => double("username" => community_merger_username)
    )
  end

  subject { described_class.new(merge_request) }

  describe '#extract_username' do
    context 'for a community contribution' do
      let(:merge_request) { community_contribution }

      it 'mentions the merger' do
        expect(subject.extract_username).to eq(community_merger_tag)
      end

      it 'mentions the assignee if the merger is not found' do
        allow(merge_request)
          .to receive(:merged_by)
          .and_return(nil)

        expect(subject.extract_username).to eq('@DouweM')
      end

      it 'mentions the author if the merger and assignee could not be found' do
        allow(merge_request)
          .to receive(:merged_by)
          .and_return(nil)

        allow(merge_request)
          .to receive(:assignee)
          .and_return(nil)

        expect(subject.extract_username).to eq('@jameslopez')
      end
    end

    context 'for a regular MR' do
      let(:merge_request) { team_mr }

      it 'mentions the author' do
        expect(subject.extract_username).to eq(team_author_tag)
      end
    end
  end
end
