# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Deployments::MergeRequestUpdater do
  describe '.for_successful_deployments' do
    it 'returns a MergeRequestUpdater operating only on successful deployments' do
      deploy = ReleaseTools::Deployments::DeploymentTracker::Deployment
        .new(ReleaseTools::Project::GitlabEe.canonical_or_security_path, 1, 'failed')

      expect(ReleaseTools::GitlabClient)
        .not_to receive(:deployed_merge_requests)

      described_class.for_successful_deployments([deploy]).add_label('foo')
    end
  end

  describe '#add_label' do
    it 'adds the label to every merge request' do
      deploy = ReleaseTools::Deployments::DeploymentTracker::Deployment
        .new(ReleaseTools::Project::GitlabEe.canonical_or_security_path, 1, 'success')

      mr1 = double(:mr, project_id: 2, iid: 3, web_url: 'foo', labels: %w[foo], source_project_id: 1)
      page = Gitlab::PaginatedResponse.new([mr1])

      expect(ReleaseTools::GitlabClient)
        .to receive(:deployed_merge_requests)
        .with(deploy.project_path, deploy.id)
        .and_return(page)

      expect(ReleaseTools::GitlabClient)
        .to receive(:update_merge_request)
        .with(2, 3, labels: 'bar,foo')

      described_class.new([deploy]).add_label('bar')
    end

    it 'removes existing scoped labels if the new label is a scoped label' do
      deploy = ReleaseTools::Deployments::DeploymentTracker::Deployment
        .new(ReleaseTools::Project::GitlabEe.canonical_or_security_path, 1, 'success')

      mr1 = double(
        :mr,
        project_id: 2,
        iid: 3,
        web_url: 'foo',
        labels: %w[workflow::canary foo],
        source_project_id: 1
      )

      page = Gitlab::PaginatedResponse.new([mr1])

      expect(ReleaseTools::GitlabClient)
        .to receive(:deployed_merge_requests)
        .with(deploy.project_path, deploy.id)
        .and_return(page)

      expect(ReleaseTools::GitlabClient)
        .to receive(:update_merge_request)
        .with(2, 3, labels: 'workflow::production,foo')

      described_class.new([deploy]).add_label('workflow::production')
    end

    it 'does not remove any scoped labels when adding a regular label' do
      deploy = ReleaseTools::Deployments::DeploymentTracker::Deployment
        .new(ReleaseTools::Project::GitlabEe.canonical_or_security_path, 1, 'success')

      mr1 = double(
        :mr,
        project_id: 2,
        iid: 3,
        web_url: 'foo',
        labels: %w[workflow::canary foo],
        source_project_id: 1
      )

      page = Gitlab::PaginatedResponse.new([mr1])

      expect(ReleaseTools::GitlabClient)
        .to receive(:deployed_merge_requests)
        .with(deploy.project_path, deploy.id)
        .and_return(page)

      expect(ReleaseTools::GitlabClient)
        .to receive(:update_merge_request)
        .with(2, 3, labels: 'kittens,workflow::canary,foo')

      described_class.new([deploy]).add_label('kittens')
    end

    it 'ignores Unprocessable errors' do
      deploy = ReleaseTools::Deployments::DeploymentTracker::Deployment
        .new(ReleaseTools::Project::GitlabEe.canonical_or_security_path, 1, 'success')

      mr1 = double(:mr, project_id: 2, iid: 3, web_url: 'foo', labels: %w[foo], source_project_id: 1)
      page = Gitlab::PaginatedResponse.new([mr1])

      expect(ReleaseTools::GitlabClient)
        .to receive(:deployed_merge_requests)
        .with(deploy.project_path, deploy.id)
        .and_return(page)

      expect(ReleaseTools::GitlabClient)
        .to receive(:update_merge_request)
        .with(2, 3, labels: 'bar,foo')
        .and_raise(gitlab_error(:Unprocessable))

      expect { described_class.new([deploy]).add_label('bar') }
        .not_to raise_error
    end

    it 'ignores MRs with a missing source_project_id' do
      deploy = ReleaseTools::Deployments::DeploymentTracker::Deployment
        .new(ReleaseTools::Project::GitlabEe.canonical_or_security_path, 1, 'success')

      mr1 = double(:mr, project_id: 2, iid: 3, web_url: 'foo', labels: %w[foo], source_project_id: nil)
      page = Gitlab::PaginatedResponse.new([mr1])

      expect(ReleaseTools::GitlabClient)
        .to receive(:deployed_merge_requests)
        .with(deploy.project_path, deploy.id)
        .and_return(page)

      expect(ReleaseTools::GitlabClient)
        .not_to receive(:update_merge_request)

      described_class.new([deploy]).add_label('bar')
    end
  end
end
