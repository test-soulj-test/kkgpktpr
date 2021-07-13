# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Security::MergeRequestValidator do
  let(:client) { double(:client) }

  describe '#validate' do
    it 'validates the merge request' do
      # All these methods are tested separately, so we just want to make sure
      # they're called from the `validate` method.
      merge_request = double(:merge_request)
      validator = described_class.new(merge_request, client)

      validation_methods = %i[
        validate_pipeline_status
        validate_merge_status
        validate_work_in_progress
        validate_pending_tasks
        validate_milestone
        validate_merge_request_template
        validate_target_branch
        validate_discussions
        validate_labels
        validate_approvals
        validate_stable_branches
      ]

      validation_methods.each do |method|
        allow(validator).to receive(method)
      end

      validator.validate

      validation_methods.each do |method|
        expect(validator).to have_received(method)
      end
    end
  end

  describe '#validate_pipeline_status' do
    let(:merge_request) { double(:merge_request) }
    let(:validator) { described_class.new(merge_request, client) }

    it 'adds an error when no pipeline could be found' do
      allow(ReleaseTools::Security::Pipeline)
        .to receive(:latest_for_merge_request)
        .with(merge_request, client)
        .and_return(nil)

      validator.validate_pipeline_status

      expect(validator.errors.first).to include('Missing pipeline')
    end

    it 'adds an error when the pipeline failed' do
      pipeline = double(:pipeline, failed?: true)

      allow(ReleaseTools::Security::Pipeline)
        .to receive(:latest_for_merge_request)
        .with(merge_request, client)
        .and_return(pipeline)

      validator.validate_pipeline_status

      expect(validator.errors.first).to include('Failing pipeline')
    end

    it 'adds an error when the pipeline is not yet finished' do
      pipeline =
        double(:pipeline, failed?: false, passed?: false, pending?: true)

      allow(ReleaseTools::Security::Pipeline)
        .to receive(:latest_for_merge_request)
        .with(merge_request, client)
        .and_return(pipeline)

      validator.validate_pipeline_status

      expect(validator.errors.first).to include('Pending pipeline')
    end

    it 'adds an error when a non-master pipeline is running' do
      pipeline =
        double(:pipeline, failed?: false, passed?: false, pending?: false, running?: true)

      allow(ReleaseTools::Security::Pipeline)
        .to receive(:latest_for_merge_request)
        .with(merge_request, client)
        .and_return(pipeline)
      allow(merge_request).to receive(:target_branch).and_return('1-2-stable-ee')

      validator.validate_pipeline_status

      expect(validator.errors.first).to include('Pending pipeline')
    end

    it 'does not add an error when the pipeline passed' do
      pipeline = double(:pipeline, failed?: false, pending?: false, running?: false)

      allow(ReleaseTools::Security::Pipeline)
        .to receive(:latest_for_merge_request)
        .with(merge_request, client)
        .and_return(pipeline)

      validator.validate_pipeline_status

      expect(validator.errors).to be_empty
    end
  end

  describe '#validate_merge_status' do
    it 'adds an error when the merge request can not be merged' do
      merge_request = double(:merge_request, merge_status: 'cannot_be_merged')
      validator = described_class.new(merge_request, client)

      validator.validate_merge_status

      expect(validator.errors.first)
        .to include('The merge request can not be merged')
    end

    it 'does not add an error when the merge request can be merged' do
      merge_request = double(:merge_request, merge_status: 'can_be_merged')
      validator = described_class.new(merge_request, client)

      validator.validate_merge_status

      expect(validator.errors).to be_empty
    end
  end

  describe '#validate_work_in_progress' do
    it 'adds an error when the merge request is a work in progress' do
      merge_request = double(:merge_request, title: 'WIP: kittens')
      validator = described_class.new(merge_request, client)

      validator.validate_work_in_progress

      expect(validator.errors.first)
        .to include('The merge request is marked as a work in progress')
    end

    it 'adds an error when the merge request is a draft' do
      merge_request = double(:merge_request, title: 'Draft: kittens')
      validator = described_class.new(merge_request, client)

      validator.validate_work_in_progress

      expect(validator.errors.first)
        .to include('The merge request is marked as a work in progress')
    end

    it 'does not add an error if the merge request is not a work in progress' do
      merge_request = double(:merge_request, title: 'kittens')
      validator = described_class.new(merge_request, client)

      validator.validate_work_in_progress

      expect(validator.errors).to be_empty
    end
  end

  describe '#validate_pending_tasks' do
    it 'adds an error when the merge request has a pending task' do
      merge_request = double(:merge_request, description: '- [ ] Todo')
      client = double(:client)
      validator = described_class.new(merge_request, client)

      validator.validate_pending_tasks

      expect(validator.errors.first)
        .to include('There are one or more pending tasks')
    end

    it 'does not add an error when all tasks are completed' do
      merge_request = double(:merge_request, description: '- [x] Todo')
      validator = described_class.new(merge_request, client)

      validator.validate_pending_tasks

      expect(validator.errors).to be_empty
    end
  end

  describe '#validate_milestone' do
    it 'adds an error when the milestone is missing' do
      merge_request = double(:merge_request, milestone: nil)
      validator = described_class.new(merge_request, client)

      validator.validate_milestone

      expect(validator.errors.first)
        .to include('The merge request does not have a milestone')
    end

    it 'does not add an error when a milestone is present' do
      merge_request =
        double(:merge_request, milestone: double(:milestone, id: 1))

      validator = described_class.new(merge_request, client)

      validator.validate_milestone

      expect(validator.errors).to be_empty
    end
  end

  describe '#validate_merge_request_template' do
    it 'adds an error when no tasks are present' do
      merge_request = double(:merge_request, description: 'Foo')
      validator = described_class.new(merge_request, client)

      validator.validate_merge_request_template

      expect(validator.errors.first)
        .to include('The Security Release template is not used')
    end

    it 'does not add an error when at least one task is present' do
      merge_request = double(:merge_request, description: '- [X] Foo')
      client = double(:client)
      validator = described_class.new(merge_request, client)

      validator.validate_merge_request_template

      expect(validator.errors).to be_empty
    end
  end

  describe '#validate_target_branch' do
    it 'adds an error when the merge request is targeting an invalid branch' do
      merge_request = double(:merge_request, target_branch: 'foo')
      validator = described_class.new(merge_request, client)

      validator.validate_target_branch

      expect(validator.errors.first).to include('The target branch is invalid')
    end

    it 'adds an error when the merge request is targeting a similar stable branch' do
      merge_request = double(:merge_request, target_branch: '13-3-stable-test-123')
      validator = described_class.new(merge_request, client)

      validator.validate_target_branch

      expect(validator.errors.first).to include('The target branch is invalid')
    end

    it 'does not add an error when the merge request targets a stable branch' do
      merge_request = double(:merge_request, target_branch: '11-8-stable')
      validator = described_class.new(merge_request, client)

      validator.validate_target_branch

      expect(validator.errors).to be_empty
    end

    it 'does not add an error when the merge request targets master' do
      merge_request = double(:merge_request, target_branch: 'master')
      validator = described_class.new(merge_request, client)

      validator.validate_target_branch

      expect(validator.errors).to be_empty
    end
  end

  describe '#validate_discussions' do
    it 'adds an error when there are unresolved discussions' do
      response = double(:response)
      merge_request = double(:merge_request, project_id: 1, iid: 2)
      discussion1 = double(notes: [{ 'resolvable' => false }])
      discussion2 =
        double(notes: [{ 'resolvable' => true, 'resolved' => false }])

      allow(response)
        .to receive(:auto_paginate)
        .and_yield(discussion1)
        .and_yield(discussion2)

      allow(client)
        .to receive(:merge_request_discussions)
        .and_return(response)

      validator = described_class.new(merge_request, client)

      validator.validate_discussions

      expect(validator.errors.first)
        .to include('There are unresolved discussions')
    end

    it 'does not add an error when there are no unresolved discussions' do
      response = double(:response)
      merge_request = double(:merge_request, project_id: 1, iid: 2)
      discussion = double(notes: [{ 'resolvable' => false }])

      allow(response)
        .to receive(:auto_paginate)
        .and_yield(discussion)

      allow(client)
        .to receive(:merge_request_discussions)
        .and_return(response)

      validator = described_class.new(merge_request, client)

      validator.validate_discussions

      expect(validator.errors).to be_empty
    end
  end

  describe '#validate_labels' do
    it 'adds an error when the security label is missing' do
      merge_request = double(:merge_request, labels: [])
      validator = described_class.new(merge_request, client)

      validator.validate_labels

      expect(validator.errors.first)
        .to include('The merge request is missing the ~security label')
    end

    it 'does not add an error when the security label is present' do
      merge_request = double(:merge_request, labels: %w[security])
      validator = described_class.new(merge_request, client)

      validator.validate_labels

      expect(validator.errors).to be_empty
    end
  end

  describe '#validate_approvals' do
    context 'when the merge request is targeting master' do
      let(:merge_request) do
        double(:merge_request,
               iid: 1,
               project_id: 1,
               target_branch: 'master')
      end

      context 'when the merge request does not have any approval' do
        it 'adds an error indicating approvals are missing' do
          approvals = double(:merge_request_approvals,
                             approvals_left: 2,
                             approval_rules_left: [])

          allow(client)
            .to receive(:merge_request_approvals)
            .with(merge_request.project_id, merge_request.iid)
            .and_return(approvals)

          validator = described_class.new(merge_request, client)
          validator.validate_approvals

          expect(validator.errors).not_to be_empty
          expect(validator.errors.first).to include("The merge request requires two approvals")
        end
      end

      context 'when the merge request only has maintainer approval' do
        it 'adds an error indicating an approval is missing' do
          approvals_rules_left = {
            id: 123,
            name: 'AppSec',
            rule_type: 'regular'
          }

          approvals = double(:merge_request_approvals,
                             approvals_left: 1,
                             approval_rules_left: [approvals_rules_left])

          allow(client)
            .to receive(:merge_request_approvals)
            .with(merge_request.project_id, merge_request.iid)
            .and_return(approvals)

          validator = described_class.new(merge_request, client)
          validator.validate_approvals

          expect(validator.errors).not_to be_empty
          expect(validator.errors.first).to include("The merge request requires two approvals")
        end
      end

      context 'when the merge request only has AppSec approval' do
        it 'adds an error indicating an approval is missing' do
          approvals_rules_left = {
            id: 456,
            name: 'All Members',
            rule_type: 'any_approver'
          }

          approvals = double(:merge_request_approvals,
                             approvals_left: 1,
                             approval_rules_left: [approvals_rules_left])

          allow(client)
            .to receive(:merge_request_approvals)
            .with(merge_request.project_id, merge_request.iid)
            .and_return(approvals)

          validator = described_class.new(merge_request, client)
          validator.validate_approvals

          expect(validator.errors).not_to be_empty
          expect(validator.errors.first).to include("The merge request requires two approvals")
        end
      end

      context 'when the merge request has maintainer and AppSec approval' do
        it 'does not add an error' do
          approvals = double(:merge_request_approvals,
                             approvals_left: 0,
                             approval_rules_left: [])

          allow(client)
            .to receive(:merge_request_approvals)
            .with(merge_request.project_id, merge_request.iid)
            .and_return(approvals)

          validator = described_class.new(merge_request, client)
          validator.validate_approvals

          expect(validator.errors).to be_empty
        end
      end
    end

    context 'when the merge request is targeting a stable branch' do
      let(:merge_request) do
        double(:merge_request,
               iid: 1,
               project_id: 1,
               target_branch: '13-1-stable-ee')
      end

      context 'when the merge request does not have any approval' do
        it 'adds an error indicating an approval is missing' do
          approvals = double(:merge_request_approvals, approved_by: [])

          allow(client)
            .to receive(:merge_request_approvals)
            .with(merge_request.project_id, merge_request.iid)
            .and_return(approvals)

          validator = described_class.new(merge_request, client)
          validator.validate_approvals

          expect(validator.errors).not_to be_empty
          expect(validator.errors.first).to include("The merge request must be approved")
        end
      end

      context 'when the merge request has one approval' do
        it 'does not add an error' do
          approver = {
            id: '123',
            name: 'Jane Doe',
            email: 'jdoe@gitlab.com',
            username: 'jdoe'
          }

          approvals = double(:merge_request_approvals, approved_by: [approver])

          allow(client)
            .to receive(:merge_request_approvals)
            .with(merge_request.project_id, merge_request.iid)
            .and_return(approvals)

          validator = described_class.new(merge_request, client)
          validator.validate_approvals

          expect(validator.errors).to be_empty
        end
      end
    end
  end

  describe '#validate_stable_branches' do
    before do
      versions = ['13.3.1', '13.2.9', '13.1.10'].map { |version| ReleaseTools::Version.new(version) }

      allow(ReleaseTools::Versions)
        .to receive(:next_security_versions)
        .and_return(versions)
    end

    context 'when targeting master' do
      it 'does not add an error' do
        merge_request = double(:merge_request, target_branch: 'master')

        validator = described_class.new(merge_request, client)
        validator.validate_stable_branches

        expect(validator.errors).to be_empty
      end
    end

    context 'when targeting a stable branch for an unreleased version' do
      it 'does not add an error' do
        # At this point, `13-4-stable-ee` has been created but the `13.4.0`
        # version entry hasn't.
        merge_request = double(
          :merge_request,
          project_id: described_class::GITLAB_SECURITY_ID,
          target_branch: '13-4-stable-ee'
        )

        validator = described_class.new(merge_request, client)
        validator.validate_stable_branches

        expect(validator.errors).to be_empty
      end
    end

    context 'when targeting a stable branch out of policy on GitLab project' do
      it 'adds an error' do
        merge_request = double(
          :merge_request,
          project_id: described_class::GITLAB_SECURITY_ID,
          target_branch: '13-0-stable-ee'
        )

        validator = described_class.new(merge_request, client)
        validator.validate_stable_branches

        expect(validator.errors).not_to be_empty
        expect(validator.errors.first).to include('The merge request is targeting a stable branch out of the maintenance policy')
      end
    end

    context 'when targeting a stable branch out of policy' do
      it 'adds an error' do
        merge_request = double(
          :merge_request,
          project_id: 123,
          target_branch: '13-0-stable-ee'
        )

        validator = described_class.new(merge_request, client)
        validator.validate_stable_branches

        expect(validator.errors).not_to be_empty
        expect(validator.errors.first).to include('The merge request is targeting a stable branch out of the maintenance policy')
      end
    end

    context 'when targeting current stable branches' do
      it 'does not add an error' do
        merge_request1 = double(:merge_request, project_id: described_class::GITLAB_SECURITY_ID, target_branch: '13-3-stable-ee')
        merge_request2 = double(:merge_request, project_id: described_class::GITLAB_SECURITY_ID, target_branch: '13-2-stable-ee')
        merge_request3 = double(:merge_request, project_id: described_class::GITLAB_SECURITY_ID, target_branch: '13-1-stable-ee')

        [merge_request1, merge_request2, merge_request3].each do |merge_request|
          validator = described_class.new(merge_request, client)
          validator.validate_stable_branches

          expect(validator.errors).to be_empty
        end
      end
    end
  end
end
