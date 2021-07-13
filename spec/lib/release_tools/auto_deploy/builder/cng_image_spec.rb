# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::AutoDeploy::Builder::CNGImage do
  let!(:fake_client) do
    yaml = <<~EOS
      variables:
        GITLAB_ELASTICSEARCH_INDEXER_VERSION: v1.5.0
        GITLAB_VERSION: v12.6.3
        GITLAB_REF_SLUG: v12.6.3
        GITLAB_ASSETS_TAG: v12.6.3
        GITLAB_EXPORTER_VERSION: 5.1.0
        GITLAB_SHELL_VERSION: v10.3.0
        GITLAB_WORKHORSE_VERSION: v8.18.0
        GITLAB_CONTAINER_REGISTRY_VERSION: v2.7.6-gitlab
        GITALY_SERVER_VERSION: v1.77.1
        MAILROOM_VERSION: 0.10.0
    EOS

    stub_const('ReleaseTools::GitlabClient', spy(file_contents: yaml))
  end

  let(:fake_commit) { double('Commit', id: SecureRandom.hex(20)) }
  let(:branch_name) { '11-10-auto-deploy-1234' }
  let(:target_branch) { ReleaseTools::AutoDeployBranch.new(branch_name) }

  subject(:builder) { described_class.new(target_branch, fake_commit.id) }

  def stub_component_versions(version_map)
    expect(ReleaseTools::ComponentVersions)
      .to receive(:for_cng)
      .with(fake_commit.id)
      .and_return(version_map)
  end

  def stub_builder_changes(value)
    refs = value ? [] : [double(type: 'tag')]

    allow(fake_client).to receive(:commit_refs).and_return(refs)
  end

  describe '#execute' do
    let!(:tagger) do
      stub_const('ReleaseTools::AutoDeploy::Tagger::CNGImage', spy)
    end

    it 'fetches gitlab-rails component versions' do
      version_map = { 'GITLAB_VERSION' => 'abcdefgh' }
      stub_component_versions(version_map)
      stub_builder_changes(false)

      builder.execute

      expect(builder.version_map).to eq(version_map)
    end

    context 'with component changes and builder changes' do
      it 'commits changes and tags, returning true' do
        version_map = { 'GITLAB_VERSION' => 'v12.6.4' }

        stub_component_versions(version_map)
        stub_builder_changes(true)

        expect(builder).to receive(:commit).and_call_original

        without_dry_run do
          expect(builder.execute).to eq(true)
        end

        expect(fake_client).to have_received(:create_commit).with(
          described_class::PROJECT.auto_deploy_path,
          branch_name,
          'Update component versions',
          [{
            action: 'update',
            file_path: described_class::VARIABLES_FILE,
            content: a_string_including('GITLAB_VERSION: v12.6.4')
          }]
        )

        expect(tagger)
          .to have_received(:new)
          .with(target_branch, version_map, an_instance_of(ReleaseTools::ReleaseMetadata))
        expect(tagger).to have_received(:tag!)
      end
    end

    context 'with no component or builder changes' do
      it 'logs warnings but does not commit or tag, returning false' do
        stub_component_versions({})
        stub_builder_changes(false)

        expect(builder).to receive(:component_changes?).and_return(false)

        expect(builder).not_to receive(:commit)
        expect(builder).not_to receive(:tag)
        expect(builder.logger).to receive(:warn).twice.and_call_original

        expect(builder.execute).to eq(false)
      end
    end
  end
end
