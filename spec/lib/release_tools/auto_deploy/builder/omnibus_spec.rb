# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::AutoDeploy::Builder::Omnibus do
  let!(:fake_client) { stub_const('ReleaseTools::GitlabClient', spy('FakeClient')) }

  let(:fake_commit) { double('Commit', id: SecureRandom.hex(20)) }
  let(:branch_name) { '11-10-auto-deploy-1234' }
  let(:target_branch) { ReleaseTools::AutoDeployBranch.new(branch_name) }
  let(:version_map) do
    {
      'GITALY_SERVER_VERSION' => '1.33.0',
      'GITLAB_ELASTICSEARCH_INDEXER_VERSION' => '1.3.0',
      'GITLAB_PAGES_VERSION' => '1.5.0',
      'GITLAB_SHELL_VERSION' => '9.0.0',
      'GITLAB_WORKHORSE_VERSION' => '8.6.0',
      'VERSION' => '0cfa69752d82b8e134bdb8e473c185bdae26ccc2'
    }
  end

  subject(:builder) { described_class.new(target_branch, fake_commit.id) }

  def stub_component_versions(version_map)
    expect(ReleaseTools::ComponentVersions)
      .to receive(:for_omnibus)
      .with(fake_commit.id)
      .and_return(version_map)
  end

  def stub_builder_changes(value)
    refs = value ? [] : [double(type: 'tag')]

    allow(fake_client).to receive(:commit_refs).and_return(refs)
  end

  describe '#execute' do
    let!(:tagger) do
      stub_const('ReleaseTools::AutoDeploy::Tagger::Omnibus', spy)
    end

    it 'fetches gitlab-rails component versions' do
      stub_component_versions(version_map)
      stub_builder_changes(false)

      builder.execute

      expect(builder.version_map).to eq(version_map)
    end

    context 'with component changes and builder changes' do
      it 'commits changes and tags, returning true' do
        # Limit the amount of files we have to stub
        version_map.slice!('VERSION')

        stub_component_versions(version_map)
        stub_builder_changes(true)

        expect(fake_client).to receive(:file_contents)
          .with(described_class::PROJECT.auto_deploy_path, 'VERSION', branch_name)
          .and_return('changed!')
        expect(builder).to receive(:commit).and_call_original

        without_dry_run do
          expect(builder.execute).to eq(true)
        end

        expect(fake_client).to have_received(:create_commit).with(
          described_class::PROJECT.auto_deploy_path,
          branch_name,
          'Update component versions',
          array_including(
            action: 'update',
            file_path: '/VERSION',
            content: "#{version_map['VERSION']}\n"
          )
        )

        expect(tagger)
          .to have_received(:new)
          .with(target_branch, version_map, an_instance_of(ReleaseTools::ReleaseMetadata))
        expect(tagger).to have_received(:tag!)
      end
    end

    context 'with no component or builder changes' do
      it 'logs warnings but does not commit or tag, returning false' do
        stub_component_versions(version_map)
        stub_builder_changes(false)

        version_map.each do |filename, contents|
          expect(fake_client).to receive(:file_contents)
            .with(described_class::PROJECT.auto_deploy_path, filename, branch_name)
            .and_return(contents)
        end

        expect(builder).not_to receive(:commit)
        expect(builder).not_to receive(:tag)
        expect(builder.logger).to receive(:warn).twice.and_call_original

        expect(builder.execute).to eq(false)
      end
    end
  end
end
