# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Services::SyncBranchesHelper do
  describe '#sync_branches' do
    before do
      foo_class = Class.new do
        include ::SemanticLogger::Loggable
        include ReleaseTools::Services::SyncBranchesHelper
      end

      stub_const('FooClass', foo_class)
    end

    let(:foo_class) { FooClass.new }

    let(:project) { ReleaseTools::Project::GitlabEe }

    let(:fake_repo) do
      instance_double(ReleaseTools::RemoteRepository).as_null_object
    end

    context 'with invalid remotes' do
      it 'does nothing' do
        stub_const("ReleaseTools::Project::GitlabEe::REMOTES", {})

        expect(ReleaseTools::RemoteRepository).not_to receive(:get)

        foo_class.sync_branches(project, 'branch')
      end
    end

    context 'with dry_run' do
      it 'does nothing' do
        branch = '1-2-stable-ee'

        expect(ReleaseTools::RemoteRepository).not_to receive(:get)

        expect(fake_repo).not_to receive(:merge)

        foo_class.sync_branches(project, branch)
      end
    end

    context 'with a successful merge' do
      it 'merges branch and pushes' do
        branch = '1-2-stable-ee'

        successful_merge = double(status: double(success?: true))

        expect(ReleaseTools::RemoteRepository).to receive(:get)
          .with(
            a_hash_including(project::REMOTES),
            a_hash_including(branch: branch)
          ).and_return(fake_repo)

        expect(fake_repo).to receive(:merge)
          .with("dev/#{branch}", no_ff: true)
          .and_return(successful_merge)

        expect(fake_repo).to receive(:push_to_all_remotes).with(branch)

        without_dry_run do
          foo_class.sync_branches(project, branch)
        end
      end
    end

    context 'with a failed merge' do
      it 'logs a fatal message with the output' do
        branch = '1-2-stable-ee'

        failed_merge = double(status: double(success?: false), output: 'output')

        allow(ReleaseTools::RemoteRepository)
          .to receive(:get)
          .and_return(fake_repo)

        expect(fake_repo).to receive(:merge).and_return(failed_merge)
        expect(fake_repo).not_to receive(:push_to_all_remotes)

        expect(foo_class.logger).to receive(:fatal)
          .with(anything, a_hash_including(output: 'output'))

        without_dry_run do
          foo_class.sync_branches(project, branch)
        end
      end
    end
  end
end
