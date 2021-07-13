# frozen_string_literal: true

require 'spec_helper'
require 'release_tools/tasks'

describe ReleaseTools::Tasks::Components::UpdateGitaly do
  subject(:task) do
    ClimateControl.modify(GITLAB_BOT_PRODUCTION_TOKEN: 'a-token') do
      described_class.new
    end
  end

  describe '.new' do
    it 'fails when GITLAB_BOT_PRODUCTION_TOKEN is not availabe' do
      ClimateControl.modify(GITLAB_BOT_PRODUCTION_TOKEN: nil) do
        expect { described_class.new }.to raise_error('key not found: "GITLAB_BOT_PRODUCTION_TOKEN"')
      end
    end
  end

  describe '#execute' do
    context 'when there are no chenges' do
      it 'does nothing' do
        expect(task).to receive(:changed?).and_return(false)

        expect(task).not_to receive(:merge_request)
        expect(task).not_to receive(:ensure_source_branch_exists)
        expect(task).not_to receive(:create_or_show_merge_request)
        expect(ReleaseTools::Services::UpdateComponentService)
          .not_to receive(:new)
        expect(task).not_to receive(:merge_when_pipeline_succeeds)

        without_dry_run do
          task.execute
        end
      end
    end

    context 'when the merge request already exists' do
      it 'sends a notification if MR is stale' do
        expect(task).to receive(:changed?).and_return(true)
        merge_request = double('merge_request', exists?: true, notifiable?: true, url: 'an url')
        allow(task).to receive(:merge_request).and_return(merge_request)

        expect(task).not_to receive(:create_merge_request)
        expect(ReleaseTools::Slack::AutoDeployNotification)
          .to receive(:on_stale_gitaly_merge_request)
          .with(merge_request)
        expect(merge_request).to receive(:mark_as_stale)

        without_dry_run do
          task.execute
        end
      end

      it 'does nothing when not notifiable' do
        expect(task).to receive(:changed?).and_return(true)
        merge_request = double('merge_request', exists?: true, notifiable?: false, url: 'an url')
        allow(task).to receive(:merge_request).and_return(merge_request)

        expect(task).not_to receive(:create_merge_request)
        expect(task).not_to receive(:notify_stale_merge_request)

        without_dry_run do
          task.execute
        end
      end
    end

    context 'when the merge request does not exist' do
      it 'makes sure the source branch exists, creates the merge request, updates gitaly versions, and set MWPS' do
        expect(task).to receive(:changed?).and_return(true)
        merge_request = double('merge_request', exists?: false)
        allow(task).to receive(:merge_request).and_return(merge_request)

        expect(task).to receive(:ensure_source_branch_exists)
        expect(task).to receive(:create_or_show_merge_request).with(merge_request)

        update_component_service = double('service')
        expect(ReleaseTools::Services::UpdateComponentService)
          .to receive(:new)
          .with(ReleaseTools::Project::Gitaly, task.source_branch_name)
          .and_return(update_component_service)

        expect(update_component_service).to receive(:execute)

        expect(task).to receive(:merge_when_pipeline_succeeds)

        without_dry_run do
          task.execute
        end
      end
    end
  end

  describe '#ensure_source_branch_exist' do
    it 'delegates to GitlabClient.find_or_create_branch' do
      branch = double('branch')
      expect(ReleaseTools::GitlabClient)
        .to receive(:find_or_create_branch)
        .with(task.source_branch_name, 'master', described_class::TARGET_PROJECT)
        .and_return(branch)

      without_dry_run do
        expect(task.ensure_source_branch_exists).to eq(branch)
      end
    end
  end

  describe '#changed?' do
    it 'checks for changes in master' do
      changed = double('changed?')
      expect(ReleaseTools::Services::UpdateComponentService)
        .to receive(:new)
        .with(ReleaseTools::Project::Gitaly, 'master')
        .and_return(double('service', changed?: changed))

      expect(task.changed?).to eq(changed)
    end
  end

  describe '#merge_request' do
    it 'is a merge request from source_branch' do
      expect(ReleaseTools::UpdateGitalyMergeRequest)
        .to receive(:new)
        .with(source_branch: task.source_branch_name)

      task.merge_request
    end
  end

  describe '#merge_when_pipeline_succeeds' do
    it 'set MWPS with the gitlab_bot_token' do
      allow(task).to receive(:merge_request).and_return(double('merge_request', url: 'a url'))

      service = double('service')
      expect(ReleaseTools::Services::MergeWhenPipelineSucceedsService)
        .to receive(:new)
        .with(task.merge_request, token: 'a-token')
        .and_return(service)
      expect(service).to receive(:execute)

      task.merge_when_pipeline_succeeds
    end
  end
end
