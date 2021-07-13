# frozen_string_literal: true

require 'spec_helper'
require 'release_tools/tasks'

RSpec.describe ReleaseTools::Tasks::AutoDeploy::Tag do
  let!(:fake_client) { stub_const('ReleaseTools::GitlabOpsClient', spy) }

  subject(:task) { described_class.new }

  around do |ex|
    ClimateControl.modify(AUTO_DEPLOY_BRANCH: '42-1-auto-deploy-2021010200') do
      ex.run
    end
  end

  def stub_coordinator_tags
    allow(fake_client).to receive(:tags).and_return([
      double(name: '14.0.202106101820')
    ])
  end

  def stub_passing_build(commit_id)
    passing_build = instance_double(
      'PassingBuild',
      execute: double('Commit', id: commit_id)
    )

    allow(ReleaseTools::PassingBuild).to receive(:new)
      .and_return(passing_build)
  end

  def stub_deploy_version(ref: '123')
    stub_coordinator_tags

    metadata = {
      'releases' => {
        'omnibus-gitlab-ee' => { 'ref' => ref }
      }
    }

    allow(fake_client)
      .to receive(:release_metadata)
      .and_return(metadata)
  end

  after do
    FileUtils.rm_r('deploy_vars.env') if File.exist?('deploy_vars.env')
  end

  describe '#execute' do
    it 'performs a full tagging run' do
      expect(task).to receive(:notify)
      expect(task).to receive(:find_passing_build)

      expect(task).to receive(:build_omnibus).and_return(false)
      expect(task).to receive(:build_cng).and_return(true)
      expect(task).to receive(:tag_coordinator)

      expect(task).to receive(:store_deploy_version)
      expect(task).to receive(:sentry_release)
      expect(task).to receive(:upload_metadata)

      task.execute
    end

    it 'does not tag coordinator without builder changes' do
      expect(task).to receive(:notify)
      expect(task).to receive(:find_passing_build)

      expect(task).to receive(:build_omnibus).and_return(false)
      expect(task).to receive(:build_cng).and_return(false)
      expect(task).not_to receive(:tag_coordinator)

      expect(task).to receive(:store_deploy_version)
      expect(task).to receive(:sentry_release)
      expect(task).to receive(:upload_metadata)

      task.execute
    end

    context 'without a coordinator pipeline' do
      it 'does not execute specific tasks' do
        allow(ReleaseTools::AutoDeploy).to receive(:coordinator_pipeline?)
          .and_return(false)

        expect(task).to receive(:notify)
        expect(task).to receive(:find_passing_build)

        expect(task).to receive(:build_omnibus).and_return(false)
        expect(task).to receive(:build_cng).and_return(true)
        expect(task).to receive(:tag_coordinator)

        expect(task).not_to receive(:store_deploy_version)
        expect(task).not_to receive(:sentry_release)
        expect(task).not_to receive(:upload_metadata)

        task.execute
      end
    end
  end

  describe '#find_passing_build' do
    it 'finds a passing build' do
      passing_build = stub_const('ReleaseTools::PassingBuild', spy)

      task.find_passing_build

      expect(passing_build).to have_received(:new).with(task.branch.to_s)
      expect(passing_build).to have_received(:execute)
    end
  end

  describe '#build_omnibus' do
    it 'executes Omnibus builder' do
      stub_coordinator_tags
      stub_passing_build('b81056529d1f')
      builder = stub_const('ReleaseTools::AutoDeploy::Builder::Omnibus', spy)

      task.build_omnibus

      expect(builder).to have_received(:new)
        .with(task.branch, 'b81056529d1f', task.metadata)
      expect(builder).to have_received(:execute)
    end
  end

  describe '#build_cng' do
    it 'executes CNG builder' do
      stub_coordinator_tags
      stub_passing_build('79def06ea756')
      builder = stub_const('ReleaseTools::AutoDeploy::Builder::CNGImage', spy)

      task.build_cng

      expect(builder).to have_received(:new)
        .with(task.branch, '79def06ea756', task.metadata)
      expect(builder).to have_received(:execute)
    end
  end

  describe '#tag_coordinator' do
    it 'executes Coordinator tagger' do
      tagger = stub_const('ReleaseTools::AutoDeploy::Tagger::Coordinator', spy)

      task.tag_coordinator

      expect(tagger).to have_received(:new)
      expect(tagger).to have_received(:tag!)
    end
  end

  describe '#sentry_release' do
    it 'tracks a Sentry release' do
      stub_passing_build('cdec0111a65a')
      tracker = stub_const('ReleaseTools::Deployments::SentryTracker', spy)

      task.sentry_release

      expect(tracker).to have_received(:new)
      expect(tracker).to have_received(:release).with('cdec0111a65a')
    end
  end

  describe '#upload_metadata' do
    it 'uploads release metadata in a coordinator pipeline' do
      stub_coordinator_tags

      uploader = stub_const('ReleaseTools::ReleaseMetadataUploader', spy)

      expect(ReleaseTools::AutoDeploy::Tag).to receive(:current)
        .and_return('1.2.3')

      task.upload_metadata

      expect(uploader).to have_received(:new)
      expect(uploader).to have_received(:upload)
        .with('1.2.3', task.metadata)
    end
  end

  describe '#prepopulate_metadata' do
    it 'fetches the latest metadata and returns a pre-populated instance' do
      metadata = {
        releases: {
          'gitlab-ee' => {
            version: '1.2.3',
            sha: '123abc',
            ref: 'auto-deploy',
            tag: false
          }
        }
      }.stringify_keys

      # NOTE: Returning `nil` as the "latest" tag to verify it's never actually used
      expect(fake_client).to receive(:tags).and_return([nil, double(name: 'v42.1.1')])
      expect(fake_client).to receive(:release_metadata).and_return(metadata)

      instance = described_class.new
      meta = instance.metadata

      expect(meta).to be_instance_of(ReleaseTools::ReleaseMetadata)
      expect(meta.releases.size).to eq(1)
      expect(meta.releases['gitlab-ee'].version).to eq('1.2.3')
      expect(meta.releases['gitlab-ee'].sha).to eq('123abc')
      expect(meta.releases['gitlab-ee'].ref).to eq('auto-deploy')
      expect(meta.releases['gitlab-ee'].tag).to eq(false)
    end

    it 'allows prepopulated metadata to be empty' do
      # NOTE: Returning `nil` as the "latest" tag to verify it's never actually used
      expect(fake_client).to receive(:tags).and_return([nil, double(name: 'v42.1.1')])
      expect(fake_client).to receive(:release_metadata).and_return({})

      instance = described_class.new
      meta = instance.metadata

      expect(meta).to be_instance_of(ReleaseTools::ReleaseMetadata)
      expect(meta.releases).to be_empty
    end

    it 'raises an error if fetching tags fails' do
      expect(fake_client).to receive(:tags).and_raise('Oh noes!')

      instance = described_class.new

      expect { instance.metadata }.to raise_error('Oh noes!')
    end
  end

  describe '#store_deploy_version' do
    it 'stores deploy_version in an env variable' do
      stub_deploy_version

      without_dry_run do
        task.store_deploy_version
      end

      expect(File.read('deploy_vars.env')).to eq('DEPLOY_VERSION=123')
    end

    it 'formats deploy packages' do
      stub_deploy_version(ref: '14.0.202105311735+ac7ff9aa2f2.2ab4d081326')

      result = 'DEPLOY_VERSION=14.0.202105311735-ac7ff9aa2f2.2ab4d081326'

      without_dry_run do
        task.store_deploy_version
      end

      expect(File.read('deploy_vars.env')).to eq(result)
    end

    it 'does nothing in dry-run mode' do
      stub_deploy_version

      task.store_deploy_version

      expect(File).not_to exist('deploy_vars.env')
    end
  end
end
