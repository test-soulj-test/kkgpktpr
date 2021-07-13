# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::GitlabClient do
  describe 'internal client delegates' do
    let(:internal_client) { instance_double(Gitlab::Client) }

    before do
      allow(described_class).to receive(:client).and_return(internal_client)
    end

    it 'delegates .job_play' do
      expect(internal_client).to receive(:job_play)

      described_class.job_play('foo', 'bar')
    end
  end

  describe '.current_user' do
    after do
      # HACK: Prevent cross-test pollution with the `.approve_merge_request` spec
      described_class.instance_variable_set(:@current_user, nil)
    end

    it 'returns the current user', vcr: { cassette_name: 'current_user' } do
      expect(described_class.current_user).not_to be_nil
    end
  end

  describe '.pipelines', vcr: { cassette_name: 'pipelines' } do
    it 'returns project pipelines' do
      response = described_class.pipelines

      expect(response.map(&:web_url)).to all(include('/pipelines/'))
    end
  end

  describe '.pipeline', vcr: { cassette_name: 'pipeline' } do
    it 'returns project pipeline' do
      pipeline_id = '55053803'
      response = described_class.pipeline(ReleaseTools::Project::GitlabCe, pipeline_id)

      expect(response.web_url).to include("/pipelines/#{pipeline_id}")
    end
  end

  describe '.pipeline_jobs', vcr: { cassette_name: 'pipeline_jobs' } do
    it 'returns pipeline jobs' do
      response = described_class.pipeline_jobs(ReleaseTools::Project::GitlabCe, '55053803')

      expect(response.map(&:web_url)).to all(include('/jobs/'))
    end
  end

  describe '.pipeline_job_by_name', vcr: { cassette_name: 'pipeline_job_by_name' } do
    it 'returns first pipeline job by name' do
      job_name = 'setup-test-env'
      response = described_class.pipeline_job_by_name(ReleaseTools::Project::GitlabCe, '55053803', job_name)

      expect(response.name).to eq(job_name)
    end
  end

  describe '.job_trace', vcr: { cassette_name: 'job_trace' } do
    it 'returns job trace' do
      response = described_class.job_trace(ReleaseTools::Project::GitlabCe, '189985934')

      expect(response).to include('mkdir -p rspec_flaky/')
    end
  end

  describe '.milestones', vcr: { cassette_name: 'merge_requests/with_milestone' } do
    # FIXME (rspeicher): See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1032"
    xit 'returns a combination of project and group milestones' do
      response = described_class.milestones

      expect(response.map(&:title)).to include('9.4', '10.4')
    end
  end

  describe '.current_milestone', vcr: { cassette_name: 'milestones/all' } do
    # FIXME (rspeicher): See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1032"
    xit 'detects the earliest current milestone' do
      Timecop.travel(Date.new(2018, 5, 11)) do
        current = described_class.current_milestone

        expect(current.title).to eq('10.8')
      end
    end

    # FIXME (rspeicher): See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1032"
    xit 'falls back to MissingMilestone' do
      Timecop.travel(Date.new(2032, 8, 3)) do
        expect(described_class.current_milestone)
          .to be_kind_of(described_class::MissingMilestone)
      end
    end
  end

  describe '.milestone', vcr: { cassette_name: 'merge_requests/with_milestone' } do
    context 'when the milestone title is nil' do
      # FIXME (rspeicher): See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1032"
      xit 'returns a MissingMilestone' do
        milestone = described_class.milestone(title: nil)

        expect(milestone).to be_a(described_class::MissingMilestone)
        expect(milestone.id).to be_nil
      end
    end

    context 'when the milestone exists' do
      # FIXME (rspeicher): See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1032"
      xit 'returns the milestone' do
        response = described_class.milestone(title: '9.4')

        expect(response.title).to eq('9.4')
      end
    end

    context 'when the milestone does not exist' do
      # FIXME (rspeicher): See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1032"
      xit 'raises an exception' do
        expect { described_class.milestone(title: 'not-existent') }.to raise_error('Milestone not-existent not found for project gitlab-org/gitlab-foss!')
      end
    end
  end

  describe '.accept_merge_request' do
    before do
      allow(described_class).to receive(:current_user).and_return(double(id: 42))
    end

    let(:merge_request) do
      double(
        project: double(path: 'gitlab-org/gitlab-foss'),
        title: 'Upstream MR',
        iid: '12345',
        description: 'Hello world',
        labels: 'CE upstream',
        source_branch: 'feature',
        target_branch: 'master',
        milestone: nil)
    end

    let(:default_params) do
      {
        merge_when_pipeline_succeeds: true
      }
    end

    it 'accepts a merge request against master on the GitLab CE project' do
      expect(described_class.__send__(:client))
        .to receive(:accept_merge_request).with(
          ReleaseTools::Project::GitlabCe.path,
          merge_request.iid,
          default_params)

      described_class.accept_merge_request(merge_request)
    end

    context 'when passing a project' do
      it 'accepts a merge request in the given project' do
        expect(described_class.__send__(:client))
          .to receive(:accept_merge_request).with(
            ReleaseTools::Project::GitlabEe.path,
            merge_request.iid,
            default_params)

        described_class
          .accept_merge_request(merge_request, ReleaseTools::Project::GitlabEe)
      end
    end
  end

  describe '.create_merge_request' do
    before do
      allow(described_class).to receive_messages(
        current_user: double(id: 42),
        current_milestone: double(id: 1)
      )
    end

    let(:merge_request) do
      double(
        project: double(path: 'gitlab-org/gitlab-foss'),
        title: 'Upstream MR',
        description: 'Hello world',
        labels: 'CE upstream',
        source_branch: 'feature',
        target_branch: 'master',
        milestone: nil)
    end

    let(:default_params) do
      {
        description: merge_request.description,
        assignee_id: 42,
        labels: merge_request.labels,
        source_branch: merge_request.source_branch,
        target_branch: 'master',
        milestone_id: 1,
        remove_source_branch: true
      }
    end

    it 'creates a merge request against master on the GitLab CE project' do
      expect(described_class.__send__(:client))
        .to receive(:create_merge_request).with(
          ReleaseTools::Project::GitlabCe.path,
          merge_request.title,
          default_params)

      described_class.create_merge_request(merge_request)
    end

    context 'when passing a project' do
      it 'creates a merge request in the given project' do
        expect(described_class.__send__(:client))
          .to receive(:create_merge_request).with(
            ReleaseTools::Project::GitlabEe.path,
            merge_request.title,
            default_params)

        described_class.create_merge_request(merge_request, ReleaseTools::Project::GitlabEe)
      end
    end

    context 'when merge request has a target branch' do
      before do
        allow(merge_request).to receive(:target_branch).and_return('stable')
      end

      it 'creates a merge request against the given target branch' do
        expect(described_class.__send__(:client))
          .to receive(:create_merge_request).with(
            ReleaseTools::Project::GitlabEe.path,
            merge_request.title,
            default_params.merge(target_branch: 'stable'))

        described_class.create_merge_request(merge_request, ReleaseTools::Project::GitlabEe)
      end
    end

    context 'with milestone', vcr: { cassette_name: 'merge_requests/with_milestone' } do
      # FIXME (rspeicher): See https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/1032"
      xit 'sets milestone id' do
        allow(merge_request).to receive(:milestone).and_return('9.4')

        response = described_class.create_merge_request(merge_request)

        expect(response.milestone.title).to eq '9.4'
      end
    end
  end

  describe '.find_issue' do
    context 'when issue is open' do
      it 'finds issues by title', vcr: { cassette_name: 'issues/release-8-7' } do
        version = double(milestone_name: '8.7')
        issue = double(title: 'Release 8.7', labels: 'Release', version: version)

        expect(described_class.find_issue(issue)).not_to be_nil
      end
    end

    context 'when issue is closed' do
      it 'finds issues by title', vcr: { cassette_name: 'issues/regressions-8-5' } do
        version = double(milestone_name: '8.5')
        issue = double(title: '8.5 Regressions', labels: 'Release', state_filter: nil, version: version)

        expect(described_class.find_issue(issue)).not_to be_nil
      end
    end

    context 'when issue cannot be found' do
      it 'does not find non-matching issues', vcr: { cassette_name: 'issues/release-7-14' } do
        version = double(milestone_name: '7.14')
        issue = double(title: 'Release 7.14', labels: 'Release', version: version)

        expect(described_class.find_issue(issue)).to be_nil
      end
    end
  end

  describe '.find_merge_request' do
    context 'when merge request is open' do
      it 'finds merge requests by title', vcr: { cassette_name: 'merge_requests/related-issues-ux-improvments' } do
        merge_request = double(title: 'Related Issues UX improvements - loading', labels: 'Discussion')

        expect(described_class.find_merge_request(merge_request, ReleaseTools::Project::GitlabEe)).not_to be_nil
      end
    end

    context 'when merge request is merged' do
      it 'does not find merged merge requests', vcr: { cassette_name: 'merge_requests/fix-geo-middleware' } do
        merge_request = double(title: 'Fix Geo middleware to work properly with multiple requests', labels: 'geo')

        expect(described_class.find_merge_request(merge_request, ReleaseTools::Project::GitlabEe)).to be_nil
      end
    end

    context 'when merge request cannot be found' do
      it 'does not find non-matching merge requests', vcr: { cassette_name: 'merge_requests/foo' } do
        merge_request = double(title: 'Foo', labels: 'Release')

        expect(described_class.find_merge_request(merge_request, ReleaseTools::Project::GitlabEe)).to be_nil
      end
    end
  end

  describe '.link_issues' do
    let(:internal_client) { instance_double(Gitlab::Client) }

    before do
      allow(described_class).to receive(:client).and_return(internal_client)
    end

    it 'links an issue to a target' do
      issue = instance_double(
        ReleaseTools::PatchIssue,
        project: ReleaseTools::Project::GitlabCe,
        iid: 1
      )
      target = instance_double(
        ReleaseTools::MonthlyIssue,
        project: ReleaseTools::Project::GitlabEe,
        iid: 2
      )

      allow(internal_client).to receive(:url_encode)
        .with('gitlab-org/gitlab-foss')
        .and_return('gitlab-org%2Fgitlab-foss')
      expect(internal_client).to receive(:post).with(
        '/projects/gitlab-org%2Fgitlab-foss/issues/1/links',
        query: { target_project_id: 'gitlab-org/gitlab', target_issue_iid: 2 }
      )

      described_class.link_issues(issue, target)
    end
  end

  describe '.find_branch' do
    it 'finds existing branches', vcr: { cassette_name: 'branches/9-4-stable' } do
      expect(described_class.find_branch('9-4-stable').name).to eq '9-4-stable'
    end

    it "returns nil when branch can't be found", vcr: { cassette_name: 'branches/9-4-stable-doesntexist' } do
      expect(described_class.find_branch('9-4-stable-doesntexist')).to be_nil
    end
  end

  describe '.create_branch' do
    it 'creates a branch', vcr: { cassette_name: 'branches/create-test' } do
      branch_name = 'test-branch-from-release-tools'

      response = described_class.create_branch(branch_name, 'master')

      expect(response.name).to eq branch_name
    end
  end

  describe '.cherry_pick' do
    context 'on a successful pick' do
      it 'returns a reasonable response', vcr: { cassette_name: 'cherry_pick/success' } do
        ref = '59af98f133ee229479c6159b15391deb4782a294'

        response = described_class.cherry_pick(ref: ref, target: '11-4-stable')

        expect(response.message).to include("cherry picked from commit #{ref}")
      end

      it 'allows passing of a custom commit message' do
        expect(described_class.client).to receive(:cherry_pick_commit).with(
          ReleaseTools::Project::GitlabCe.path,
          '123abc',
          'master',
          dry_run: false,
          message: 'foo'
        )

        described_class
          .cherry_pick(ref: '123abc', target: 'master', message: 'foo')
      end

      it 'does not pass the message argument to the API when left out' do
        expect(described_class.client).to receive(:cherry_pick_commit).with(
          ReleaseTools::Project::GitlabCe.path,
          '123abc',
          'master',
          dry_run: false
        )

        described_class.cherry_pick(ref: '123abc', target: 'master')
      end
    end

    context 'on a failed pick' do
      it 'raises an exception', vcr: { cassette_name: 'cherry_pick/failure' } do
        expect do
          described_class.cherry_pick(
            ref: '396d205e5a503f9f48c223804087a80f7acc6d06',
            target: '11-4-stable'
          )
        end.to raise_error(Gitlab::Error::BadRequest)
      end
    end

    context 'on an invalid ref' do
      it 'raises an `ArgumentError`' do
        expect { described_class.cherry_pick(ref: '', target: 'foo') }
          .to raise_error(ArgumentError)
      end
    end
  end

  describe '.project_path' do
    it 'returns the correct project path' do
      project = double(path: 'foo/bar')

      expect(described_class.project_path(project)).to eq 'foo/bar'
    end

    it 'returns a String unmodified' do
      project = 'gitlab-org/security/gitlab'

      expect(described_class.project_path(project)).to eq(project)
    end
  end

  describe '.related_merge_requests' do
    it 'returns the related merge requests' do
      page = double(:page)

      allow(described_class.client)
        .to receive(:get)
        .with('/projects/foo%2Fbar/issues/1/related_merge_requests')
        .and_return(page)

      expect(described_class.related_merge_requests('foo/bar', 1)).to eq(page)
    end
  end

  describe '#tree' do
    it 'lists the contents of a directory' do
      project = ReleaseTools::Project::GitlabCe
      tree = double(:tree)

      allow(described_class.client)
        .to receive(:tree)
        .with(project.path, 'foo')
        .and_return(tree)

      expect(described_class.tree(project, 'foo')).to eq(tree)
    end
  end

  describe '#get_file' do
    it 'gets a file from the repository' do
      project = ReleaseTools::Project::GitlabCe
      file = double(:file)

      allow(described_class.client)
        .to receive(:get_file)
        .with(project.path, 'foo', 'bar')
        .and_return(file)

      expect(described_class.get_file(project, 'foo', 'bar')).to eq(file)
    end
  end

  describe '#find_or_create_branch' do
    context 'when the branch exists' do
      it 'returns the branch' do
        branch = double(:branch)

        allow(described_class)
          .to receive(:find_branch)
          .with('foo', ReleaseTools::Project::GitlabCe)
          .and_return(branch)

        expect(described_class.find_or_create_branch('foo', 'master'))
          .to eq(branch)
      end
    end

    context 'when the branch does not exist' do
      it 'creates the branch' do
        branch = double(:branch)
        master = double(:branch, commit: double(:commit, id: '123'))

        allow(described_class)
          .to receive(:find_branch)
          .with('foo', ReleaseTools::Project::GitlabCe)
          .and_return(nil)

        allow(described_class)
          .to receive(:find_branch)
          .with('master', ReleaseTools::Project::GitlabCe)
          .and_return(master)

        allow(described_class)
          .to receive(:create_branch)
          .with('foo', 'master', ReleaseTools::Project::GitlabCe)
          .and_return(branch)

        expect(described_class.find_or_create_branch('foo', 'master'))
          .to eq(branch)

        expect(described_class)
          .to have_received(:create_branch)
      end
    end
  end

  describe '#find_or_create_tag' do
    context 'when the tag exists' do
      it 'returns the tag' do
        tag = double(:tag)
        project = ReleaseTools::Project::GitlabCe

        allow(described_class)
          .to receive(:tag)
          .with(project, tag: 'foo')
          .and_return(tag)

        expect(described_class.find_or_create_tag(project, 'foo', 'master'))
          .to eq(tag)
      end
    end

    context 'when the tag does not exist' do
      it 'creates the tag' do
        tag = double(:tag)
        project = ReleaseTools::Project::GitlabCe

        allow(described_class)
          .to receive(:tag)
          .with(project, tag: 'foo')
          .and_raise(gitlab_error(:NotFound))

        allow(described_class)
          .to receive(:create_tag)
          .with(project, 'foo', 'master', nil)
          .and_return(tag)

        expect(described_class.find_or_create_tag(project, 'foo', 'master'))
          .to eq(tag)
      end

      it 'supports creating annotated tags' do
        tag = double(:tag)
        project = ReleaseTools::Project::GitlabCe

        allow(described_class)
          .to receive(:tag)
          .with(project, tag: 'foo')
          .and_raise(gitlab_error(:NotFound))

        allow(described_class)
          .to receive(:create_tag)
          .with(project, 'foo', 'master', 'foo')
          .and_return(tag)

        output = described_class
          .find_or_create_tag(project, 'foo', 'master', message: 'foo')

        expect(output).to eq(tag)
      end
    end
  end

  describe '#create_tag' do
    it 'creates a tag' do
      project = ReleaseTools::Project::GitlabCe
      tag = double(:tag)

      expect(described_class.client)
        .to receive(:create_tag)
        .with(project.path, 'foo', 'master')
        .and_return(tag)

      expect(described_class.create_tag(project, 'foo', 'master')).to eq(tag)
    end
  end

  describe '#branches' do
    it 'returns the branches for a project' do
      response = double(:response)

      expect(described_class.client)
        .to receive(:branches)
        .with('gitlab-org/gitlab', search: 'foo')
        .and_return(response)

      expect(described_class.branches(ReleaseTools::Project::GitlabEe, search: 'foo'))
        .to eq(response)
    end
  end

  describe '.create_merge_request_pipeline' do
    it 'triggers a merge request pipeline' do
      response = double(:response)

      allow(described_class.client)
        .to receive(:post)
        .with('/projects/123/merge_requests/1/pipelines')
        .and_return(response)

      expect(described_class.create_merge_request_pipeline(123, 1)).to eq(response)
    end
  end

  describe '#tags' do
    it 'returns the tags of a project' do
      response = double(:response)

      expect(described_class.client)
        .to receive(:tags)
        .with('gitlab-org/gitlab', search: 'foo')
        .and_return(response)

      expect(described_class.tags(ReleaseTools::Project::GitlabEe, search: 'foo'))
        .to eq(response)
    end
  end

  describe '.create_issue' do
    let(:version) { double(:version, milestone_name: '13.6') }
    let(:milestone) { double(:milestone, id: '123') }
    let(:current_user) { double(:user, id: '123') }

    let(:issue) do
      double(:issue,
             title: 'foo',
             description: 'bar',
             confidential?: true,
             version: version,
             labels: 'baz')
    end

    let(:default_options) do
      {
        description: issue.description,
        assignee_ids: [current_user.id],
        milestone_id: milestone.id,
        labels: issue.labels,
        confidential: issue.confidential?
      }
    end

    before do
      allow(described_class)
        .to receive(:milestone).and_return(milestone)

      allow(described_class)
        .to receive(:current_user).and_return(current_user)
    end

    it 'creates an issue on the project' do
      expect(described_class.client)
        .to receive(:create_issue).with(
          ReleaseTools::Project::GitlabCe.path,
          issue.title,
          default_options
        )

      described_class.create_issue(issue)
    end

    context 'when the issue responds to assignees' do
      let(:issue) do
        double(:issue,
               title: 'foo',
               description: 'bar',
               confidential?: true,
               version: version,
               labels: 'baz',
               assignees: [456, 789])
      end

      it 'creates an issue with specific assignees' do
        options = default_options.merge(assignee_ids: [456, 789])

        expect(described_class.client)
          .to receive(:create_issue).with(
            ReleaseTools::Project::GitlabCe.path,
            issue.title,
            options
          )

        described_class.create_issue(issue)
      end
    end

    context 'when the issue responds to due_date' do
      let(:issue) do
        double(:issue,
               title: 'foo',
               description: 'bar',
               confidential?: true,
               version: version,
               labels: 'baz',
               due_date: '2020-01-01')
      end

      it 'creates an issue with the due date' do
        options = default_options.merge(due_date: '2020-01-01')

        expect(described_class.client)
          .to receive(:create_issue).with(
            ReleaseTools::Project::GitlabCe.path,
            issue.title,
            options
          )

        described_class.create_issue(issue)
      end
    end
  end

  describe '.update_or_create_deployment' do
    it 'updates an existing deployment of the same ref and SHA' do
      project = double('Project')
      environment = 'gprd'

      expect(described_class).to receive(:deployments)
        .with(project, environment, status: 'running')
        .and_return([
          double(id: 1, ref: 'master', sha: 'a', status: 'running'),
          double(id: 2, ref: 'master', sha: 'b', status: 'running'),
          double(id: 3, ref: 'master', sha: 'c', status: 'running'),
          double(id: 4, ref: 'master', sha: 'd', status: 'running')
        ])

      expect(described_class).to receive(:update_deployment)
        .with(project, 3, status: 'success')

      described_class.update_or_create_deployment(
        project,
        environment,
        ref: 'master',
        sha: 'c',
        status: 'success'
      )
    end

    it 'creates a new deployment' do
      project = double('Project')
      environment = 'gprd'

      expect(described_class).to receive(:deployments)
        .with(project, environment, status: 'running')
        .and_return([double(id: 1, ref: 'master', sha: 'a', status: 'running')])

      expect(described_class).not_to receive(:update_deployment)
      expect(described_class).to receive(:create_deployment)
        .with(project, environment, ref: 'master', sha: 'b', status: 'running', tag: false)

      described_class.update_or_create_deployment(
        project,
        environment,
        ref: 'master',
        sha: 'b',
        status: 'running'
      )
    end
  end

  describe '.compile_changelog' do
    it 'compiles the changelog' do
      expect(described_class.client).to receive(:post).with(
        "/projects/foo%2Fbar/repository/changelog",
        body: {
          version: '1.1.0',
          to: '123',
          branch: 'main',
          message: "Update changelog for 1.1.0\n\n[ci skip]"
        }
      )

      described_class.compile_changelog('foo/bar', '1.1.0', '123', 'main')
    end
  end

  describe '.commit_status' do
    it 'returns the commit statuses' do
      response = double(:response)

      expect(described_class.client)
        .to receive(:commit_status)
        .with('gitlab-org/gitlab', '123', ref: 'master')
        .and_return(response)

      result = described_class
        .commit_status(ReleaseTools::Project::GitlabEe, '123', ref: 'master')

      expect(result).to eq(response)
    end
  end

  describe '.merge_request_commits' do
    it 'returns the commits of a merge request' do
      response = double(:response)

      expect(described_class.client)
        .to receive(:merge_request_commits)
        .with(ReleaseTools::Project::GitlabCe.path, 42)
        .and_return(response)

      result = described_class
        .merge_request_commits(ReleaseTools::Project::GitlabCe, 42)

      expect(result).to eq(response)
    end
  end
end
