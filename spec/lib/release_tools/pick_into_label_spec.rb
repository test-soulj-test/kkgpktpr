# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::PickIntoLabel do
  describe '.escaped' do
    it 'returns the correct label' do
      version = instance_double('Version', to_minor: 'foo')

      expect(described_class.escaped(version)).to eq "Pick+into+foo"
    end
  end

  describe '.reference' do
    it 'returns the correct label' do
      version = instance_double('Version', to_minor: 'foo')

      expect(described_class.reference(version)).to eq '~"Pick into foo"'
    end

    it 'handles an auto-deploy version' do
      expect(described_class.reference(:auto_deploy)).to eq '~"Pick into auto-deploy"'
    end
  end

  describe '#create' do
    let(:service) { described_class.new(ReleaseTools::Version.new('11.8.0-rc1')) }

    it 'does nothing on a dry run' do
      expect(ReleaseTools::GitlabClient).not_to receive(:create_group_label)

      service.create
    end

    it 'is idempotent' do
      internal_client = stub_const('ReleaseTools::GitlabClient', spy)

      expect(internal_client).to receive(:create_group_label)
        .and_raise(gitlab_error(:BadRequest, message: 'Label already exists'))

      without_dry_run do
        expect { service.create }.not_to raise_error
      end
    end

    it 'creates the label' do
      internal_client = stub_const('ReleaseTools::GitlabClient', spy)

      without_dry_run do
        service.create
      end

      expect(internal_client).to have_received(:create_group_label).with(
        described_class::GROUP,
        'Pick into 11.8',
        described_class::COLOR,
        description: described_class::DESCRIPTION % '11-8-stable'
      )
    end
  end
end
