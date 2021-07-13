# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReleaseTools::ChangelogCompiler do
  let(:project) { 'kitten/mittens' }
  let(:client) { class_spy(ReleaseTools::GitlabClient) }
  let(:compiler) { described_class.new(project, client: client) }
  let(:version) { ReleaseTools::Version.new('1.1.0') }

  describe '#compile' do
    it 'compiles the changelog on the given branch and the default branch' do
      allow(client).to receive(:default_branch).with(project).and_return('main')

      expect(client)
        .to receive(:commit)
        .with(project, ref: '1-1-stable')
        .and_return(double(:commit, id: '123'))

      expect(compiler)
        .to receive(:compile_on_branch)
        .with(version, '1-1-stable', '123')

      expect(compiler)
        .to receive(:compile_on_branch)
        .with(version, 'main', '123')

      compiler.compile(version)
    end
  end

  describe '#compile_on_branch' do
    it 'compiles the changelog on a branch' do
      expect(client)
        .to receive(:compile_changelog)
        .with(project, '1.1.0', '123', '1-1-stable')

      compiler.compile_on_branch(version, '1-1-stable', '123')
    end

    it 'only includes the major, minor and patch version numbers' do
      version = ReleaseTools::Version.new('1.1.0-ee.0')

      expect(client)
        .to receive(:compile_changelog)
        .with(project, '1.1.0', '123', '1-1-stable')

      compiler.compile_on_branch(version, '1-1-stable', '123')
    end

    it 'only includes the major, minor and patch version numbers for an Omnibus version' do
      version = ReleaseTools::OmnibusGitlabVersion.new('1.1.0+ee.0')

      expect(client)
        .to receive(:compile_changelog)
        .with(project, '1.1.0', '123', '1-1-stable')

      compiler.compile_on_branch(version, '1-1-stable', '123')
    end

    it 'retries the operation if it fails' do
      raised = false

      allow(client).to receive(:compile_changelog) do
        if raised
          true
        else
          raised = true
          raise gitlab_error(:InternalServerError)
        end
      end

      expect { compiler.compile_on_branch(version, '1-1-stable', '123') }
        .not_to raise_error
    end
  end

  describe '#default_branch_name' do
    it 'returns the name of the default branch' do
      allow(client).to receive(:default_branch).with(project).and_return('main')

      expect(compiler.default_branch_name).to eq('main')
    end

    it 'retries the operation if it fails' do
      raised = false

      allow(client).to receive(:default_branch) do
        if raised
          'main'
        else
          raised = true
          raise gitlab_error(:InternalServerError)
        end
      end

      expect(compiler.default_branch_name).to eq('main')
    end
  end
end
