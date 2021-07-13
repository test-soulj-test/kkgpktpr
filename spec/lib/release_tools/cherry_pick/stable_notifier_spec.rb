# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::CherryPick::StableNotifier do
  let(:client) { spy('GitlabClient') }
  let(:version) { ReleaseTools::Version.new('11.4.1') }

  let(:prep_mr) do
    double(
      iid: 1,
      project_id: 2,
      url: 'https://example.com',
      release_issue: double(project: spy, iid: 4),
      pick_destination: 'https://example.com',
      branch_name: '11-4-stable-ee-patch-1'
    )
  end

  let(:merge_request) do
    double(
      iid: 3,
      project_id: 2,
      url: 'https://example.com',
      author: double(username: 'liz.lemon')
    )
  end

  def result_double(value)
    instance_double(
      'ReleaseTools::CherryPick::Result',
      title: value,
      url: value,
      to_markdown: "[#{value}](#{value})"
    )
  end

  subject do
    described_class.new(version, target: prep_mr)
  end

  before do
    allow(subject).to receive(:client).and_return(client)
  end

  around do |ex|
    without_dry_run { ex.run }
  end

  describe '#comment' do
    context 'with a successful pick' do
      it 'posts a success comment' do
        expected_url = prep_mr.url
        pick_result = ReleaseTools::CherryPick::Result.new(merge_request, :success)

        subject.comment(pick_result)

        expect(client).to have_received(:create_merge_request_comment).with(
          merge_request.project_id,
          merge_request.iid,
          StableNotifierMatchers::SuccessMessageArgument.new(version, expected_url)
        )
      end
    end

    context 'with a failed pick' do
      it 'posts a failure comment' do
        pick_result = ReleaseTools::CherryPick::Result.new(merge_request, :failure)

        subject.comment(pick_result)

        expect(client).to have_received(:create_merge_request_comment).with(
          merge_request.project_id,
          merge_request.iid,
          StableNotifierMatchers::FailureMessageArgument.new(version, merge_request.author)
        )
      end
    end
  end

  describe '#summary' do
    it 'posts a summary message to the preparation merge request' do
      picked = [result_double('a'), result_double('b')]
      unpicked = [result_double('c')]

      subject.summary(picked, unpicked)

      expect(client).to have_received(:create_merge_request_comment).with(
        prep_mr.project_id,
        prep_mr.iid,
        StableNotifierMatchers::SummaryMessageArgument.new(version, picked, unpicked)
      )
    end

    it 'excludes an empty picked list' do
      picked = []
      unpicked = [result_double('a')]

      subject.summary(picked, unpicked)

      expect(client).to have_received(:create_merge_request_comment).with(
        prep_mr.project_id,
        prep_mr.iid,
        StableNotifierMatchers::SummaryMessageArgument.new(version, picked, unpicked)
      )
    end

    it 'excludes an empty unpicked list' do
      picked = [result_double('a')]
      unpicked = []

      subject.summary(picked, unpicked)

      expect(client).to have_received(:create_merge_request_comment).with(
        prep_mr.project_id,
        prep_mr.iid,
        StableNotifierMatchers::SummaryMessageArgument.new(version, picked, unpicked)
      )
    end

    it 'does not post an empty message' do
      subject.summary([], [])

      expect(client).not_to have_received(:create_merge_request_comment)
    end
  end

  describe '#blog_post_summary' do
    it 'posts a blog post summary message to the preparation merge request' do
      picked = [result_double('a'), result_double('b')]

      subject.blog_post_summary(picked)

      expect(client).to have_received(:create_issue_note).with(
        prep_mr.release_issue.project,
        issue: prep_mr.release_issue,
        body: StableNotifierMatchers::BlogPostSummaryMessageArgument.new(version, picked)
      )
    end

    it 'does not post an empty message' do
      subject.blog_post_summary([])

      expect(client).not_to have_received(:create_merge_request_comment)
    end
  end
end

module StableNotifierMatchers
  class SuccessMessageArgument
    def initialize(version, expected_url)
      @version = version
      @expected_url = expected_url
    end

    def ===(other)
      other.include?("Automatically picked into #{@expected_url}") &&
        other.include?("will merge into\n`#{@version.stable_branch}`") &&
        other.include?("ready for `#{@version}`.") &&
        other.include?("/unlabel #{ReleaseTools::PickIntoLabel.reference(@version)}")
    end
  end

  class FailureMessageArgument
    def initialize(version, author)
      @version = version
      @author = author
    end

    def ===(other)
      other.include?("@#{@author.username}") &&
        other.include?("could\nnot automatically be picked into `#{@version.stable_branch}`") &&
        other.include?("`#{@version}` and will need manual intervention") &&
        other.include?("/unlabel #{ReleaseTools::PickIntoLabel.reference(@version)}")
    end
  end

  class SummaryMessageArgument
    def initialize(version, picked, unpicked)
      @version = version
      @picked = picked
      @unpicked = unpicked
    end

    def ===(other)
      include_picked?(other) && include_unpicked?(other)
    end

    private

    def include_picked?(other)
      if @picked.empty?
        !other.include?("Successfully picked")
      else
        other.include?("Successfully picked the following merge requests:") &&
          @picked.all? { |p| other.include?("* #{p.url}") }
      end
    end

    def include_unpicked?(other)
      if @unpicked.empty?
        !other.include?("Failed to pick")
      else
        other.include?("Failed to pick the following merge requests:") &&
          @unpicked.all? { |p| other.include?("* #{p.url}") }
      end
    end
  end

  class BlogPostSummaryMessageArgument
    def initialize(version, picked)
      @version = version
      @picked = picked
    end

    def ===(other)
      header = "The following merge requests were picked into"

      if @picked.empty?
        !other.include?(header)
      else
        other.include?(header) &&
          @picked.all? { |p| other.include?("* #{p.to_markdown}") }
      end
    end
  end
end
