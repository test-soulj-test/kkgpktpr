# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Qa::Formatters::MergeRequestsFormatter do
  let(:mr1) { mr_double('mr1', 111, ['Team 1', 'TypeA']) }
  let(:mr2) { mr_double('mr2', 222, ['Team1', 'Without Type']) }
  let(:mr3) { mr_double('mr3', 333, ['Without Team', 'TypeC']) }
  let(:merge_requests) do
    {
      "Team 1" => {
        "TypeA" => [mr1],
        "uncategorized" => [mr2]
      },
      "uncategorized" => [mr3]
    }
  end
  let(:project_path) { 'gitlab-org/gitlab-foss' }

  subject { described_class.new(merge_requests: merge_requests, project_path: project_path) }

  describe '#lines' do
    shared_examples 'lines returns correct contents' do
      it 'has the correct contents' do
        expect(subject.lines).to be_a(Array)
        expect(subject.lines.size).to eq(10)
        expect(subject.lines).to eq(
          [
            "### Team 1 ~\"Team 1\" \n",
            "#### TypeA ~\"TypeA\" \n",
            mr_string(mr1, project_path: project_path),
            "\n\n----\n\n",
            "#### uncategorized ~\"uncategorized\" \n",
            mr_string(mr2, project_path: project_path),
            "\n\n----\n\n",
            "### uncategorized ~\"uncategorized\" \n",
            mr_string(mr3, project_path: project_path),
            "\n\n----\n\n",
          ]
        )
      end
    end

    it_behaves_like 'lines returns correct contents'

    context 'for community contribution' do
      let(:mr1) { mr_double('mr1', 111, ['Team1', 'TypeA', ReleaseTools::Qa::UsernameExtractor::COMMUNITY_CONTRIBUTION_LABEL]) }

      it 'mentions the merger' do
        expect(subject.lines[2]).to include(mr1.merged_by.username)
      end
    end

    context 'when project_path is different from the MR project path' do
      let(:project_path) { 'gitlab/gitlabhq' }

      it_behaves_like 'lines returns correct contents'
    end
  end

  def mr_string(merge_request, project_path:)
    labels = merge_request.labels.map { |l| "~\"#{l}\"" }.join(' ')
    link_href = merge_request.web_url.include?(project_path) ? "#{project_path}!#{merge_request.iid}" : merge_request.web_url

    "- @#{merge_request.author.username} | [#{merge_request.title}](#{link_href}) #{labels}"
  end

  def mr_double(identifier, iid, labels)
    double(
      identifier,
      "iid" => iid,
      "labels" => labels,
      "title" => "#{identifier} Title",
      "author" => double("username" => "#{identifier}_author"),
      "assignee" => double("username" => "#{identifier}_assignee"),
      "sha" => "#{identifier}_sha",
      "merge_commit_sha" => "#{identifier}_merge_commit_sha",
      "web_url" => "https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/#{iid}",
      "merged_by" => double("username": "#{identifier}_merged_by")
    )
  end
end
