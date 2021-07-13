# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Qa::Issue do
  let(:version) { ReleaseTools::Version.new('10.8.0-rc1') }
  let(:current_date) { DateTime.new(2018, 9, 10, 16, 40, 0, '+2') }
  let(:project) { ReleaseTools::Project::GitlabEe }
  let(:mr1) do
    double(
      "title" => "Resolve \"Import/Export (import) is broken due to the addition of a CI table\"",
      "author" => double("username" => "author"),
      "assignee" => double("username" => "assignee"),
      "labels" => [
        "group::access",
        "bug",
        "import",
        "project export",
        "regression"
      ],
      "sha" => "4f04aeec80bbfcb025e321693e6ca99b01244bb4",
      "merge_commit_sha" => "0065c449ff95cf6e0643bab17ed236c23207b537",
      "web_url" => "https://gitlab.com/gitlab-org/gitlab/merge_requests/18745",
      "merged_by" => double("username" => "merger")
    )
  end

  let(:merge_requests) { [mr1] }

  let(:args) do
    {
      version: version,
      project: project,
      merge_requests: merge_requests
    }
  end

  # Disable VCR for these requests, so that we can verify them with WebMock
  # without requiring a cassette recording
  around do |ex|
    VCR.turn_off!

    ex.run

    VCR.turn_on!
  end

  before do
    stub_request(:get, "https://gitlab.com/api/v4/groups/gitlab-org/labels?search=group::&per_page=100")
      .to_return(body: [{ name: "group::access" }, { name: "group::compliance" }, { name: "devops::create" }].to_json)
  end

  subject { described_class.new(args) }

  it_behaves_like 'issuable #create', :create_issue
  it_behaves_like 'issuable #update', :update_issue
  it_behaves_like 'issuable #remote_issuable', :find_issue

  describe '#gitlab_test_instance' do
    subject(:gitlab_test_instance) { described_class.new(args).gitlab_test_instance }

    context 'for auto-deploys' do
      let(:version) { ReleaseTools::Version.new('12.3.201908250820-632c6a10c06.604eab1b429') }

      it 'returns the release instance' do
        expect(gitlab_test_instance).to eq 'https://staging.gitlab.com'
      end
    end

    context 'for RCs' do
      let(:version) { ReleaseTools::Version.new('10.8.0-rc1') }

      it 'returns the pre instance' do
        expect(gitlab_test_instance).to eq 'https://pre.gitlab.com'
      end
    end

    context 'for release packages' do
      let(:version) { ReleaseTools::Version.new('10.8.0-ee.0') }

      it 'returns the release instance' do
        expect(gitlab_test_instance).to eq 'https://release.gitlab.net'
      end
    end
  end

  describe '#title' do
    it "returns the correct issue title" do
      expect(subject.title).to eq '10.8.0-rc1 QA Issue'
    end
  end

  describe '#confidential?' do
    it 'is always confidential' do
      expect(subject).to be_confidential
    end
  end

  describe '#description' do
    context 'for a new issue' do
      let(:content) do
        Timecop.freeze(current_date) { subject.description }
      end

      before do
        expect(subject).to receive(:exists?).and_return(false)
      end

      it "includes the current release version" do
        expect(content).to include("## Merge Requests tested in 10.8.0-rc1")
      end

      it "includes the Team label title" do
        expect(content).to include('### group::access')
      end

      it "includes the MR information" do
        expect(content).to include('Import/Export (import) is broken due to the addition of a CI table')
        expect(content).to include('gitlab-org/gitlab!18745')
      end

      it "includes the MR author" do
        expect(content).to include("@author")
      end

      it "includes the qa task for version" do
        expect(content).to include("## Automated QA for 10.8.0-rc1")
      end

      it 'includes the mention of testcases report' do
        expect(content).to include('The test session report for this deployment is generated')
        expect(content).to include('Help make that happen quicker by expanding [the end-to-end test suite]')
      end

      it 'includes the due date' do
        expect(content).to include('2018-09-11 14:40 UTC')
      end

      it "includes the test endpoint for patch releases" do
        expect(content).to include("pre.gitlab.com")
      end

      context 'for RC2' do
        let(:version) { ReleaseTools::Version.new('10.8.0-rc2') }

        it 'the due date is 24h in the future' do
          expect(content).to include('2018-09-11 14:40 UTC')
        end
      end

      context 'for auto-deploy releases' do
        let(:version) { ReleaseTools::Version.new('12.3.201908250820-632c6a10c06.604eab1b429') }

        it "includes the test endpoint for auto-deploy releases" do
          expect(content).to include("staging.gitlab.com")
        end
      end

      context 'for release packages' do
        let(:version) { ReleaseTools::Version.new('10.8.0-ee.0') }

        it 'returns the release instance' do
          expect(content).to include('release.gitlab.net')
        end
      end
    end

    context 'for an existing issue' do
      let(:previous_revision) { 'Previous Revision' }
      let(:remote_issuable) do
        double(description: previous_revision)
      end

      before do
        expect(subject).to receive(:exists?).and_return(true)
        expect(subject).to receive(:remote_issuable).and_return(remote_issuable)
      end

      it "includes previous revision" do
        expect(subject.description).to include("Previous Revision")
      end
    end
  end

  describe '#labels' do
    it 'returns a list of labels' do
      expect(subject.labels).to eq 'QA task'
    end
  end

  describe '#add_comment' do
    let(:comment_body) { "comment body" }
    let(:remote_issue_iid) { 1234 }
    let(:remote_issuable) { double(iid: remote_issue_iid) }

    before do
      expect(subject).to receive(:remote_issuable).and_return(remote_issuable)
    end

    it "calls the api to create a comment" do
      expect(ReleaseTools::GitlabClient).to receive(:create_issue_note)
        .with(project, issue: remote_issuable, body: comment_body)

      subject.add_comment(comment_body)
    end
  end

  describe '#link!' do
    it 'links to its parent issue' do
      issue = described_class.new(version: version)

      parent = ReleaseTools::PatchIssue
        .new(version: ReleaseTools::Version.new(issue.version.to_minor))

      allow(issue).to receive(:parent_issue).and_return(parent)
      allow(parent).to receive(:exists?).and_return(true)

      expect(ReleaseTools::GitlabClient)
        .to receive(:link_issues)
        .with(issue, parent)

      issue.link!
    end

    it 'does not link the parent issue if it does not exist' do
      issue = described_class.new(version: version)

      parent = ReleaseTools::PatchIssue
        .new(version: ReleaseTools::Version.new(issue.version.to_minor))

      allow(issue).to receive(:parent_issue).and_return(parent)
      allow(parent).to receive(:exists?).and_return(false)

      expect(ReleaseTools::GitlabClient)
        .not_to receive(:link_issues)

      issue.link!
    end
  end

  describe '#parent_issue' do
    it 'returns an issue using the major.minor version' do
      issue = described_class.new(
        version: ReleaseTools::Version.new('12.9.202002181205-672677036cb.7875146729a')
      )

      expect(issue.parent_issue.version).to eq('12.9.0')
    end
  end

  describe '#create?' do
    it 'returns true when there are merge requests' do
      expect(subject.create?).to eq(true)
    end

    it 'returns false when there are no merge requests' do
      issue = described_class.new(
        version: version,
        project: project,
        merge_requests: []
      )

      expect(issue.create?).to eq(false)
    end
  end
end
