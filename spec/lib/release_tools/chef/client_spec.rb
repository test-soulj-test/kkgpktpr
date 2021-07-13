# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Chef::Client do
  let(:client) do
    ClimateControl.modify(
      CHEF_API_KEY: '/path/to/some/key',
      CHEF_API_ENDPOINT: 'https://example.com',
      CHEF_API_CLIENT: 'some-client'
    ) do
      described_class.new('some-env')
    end
  end

  let(:chef_role) { instance_double('Chef Role') }

  before do
    allow(ChefAPI::Connection)
      .to receive(:new)
      .and_return(
        instance_double(
          'ChefAPI::Connection',
          roles: chef_role
        )
      )
  end

  context 'when omnibus role results are empty' do
    let(:empty_role) do
      instance_double(
        'empty role result',
        default_attributes: {}
      )
    end

    before do
      allow(chef_role)
        .to receive(:fetch)
        .with('some-env-omnibus-version')
        .and_return(empty_role)
    end

    describe '#environment_enabled?' do
      it 'returns unlocked by default' do
        expect(client.environment_enabled?).to eq(true)
      end
    end

    describe 'pipeline_url' do
      it 'returns unknown by default' do
        expect(client.pipeline_url).to eq('unknown')
      end
    end
  end

  context 'when omnibus role is enabled' do
    let(:enabled_role) do
      instance_double(
        'role result',
        default_attributes: {
          'omnibus-gitlab' => {
            'package' => {
              'enable' => true
            }
          }
        }
      )
    end

    before do
      allow(chef_role)
        .to receive(:fetch)
        .with('some-env-omnibus-version')
        .and_return(enabled_role)
    end

    describe '#environment_enabled?' do
      it 'returns an enabled role' do
        expect(client.environment_enabled?).to eq(true)
      end
    end
  end

  context 'when omnibus role is disabled' do
    let(:disabled_role) do
      instance_double(
        'role result',
        default_attributes: {
          'omnibus-gitlab' => {
            'package' => {
              'enable' => false,
              '__CI_PIPELINE_URL' => 'https://example.com/some/pipeline/url'
            }
          }
        }
      )
    end

    before do
      allow(chef_role)
        .to receive(:fetch)
        .with('some-env-omnibus-version')
        .and_return(disabled_role)
    end

    describe '#environment_enabled?' do
      it 'returns a disabled role' do
        expect(client.environment_enabled?).to eq(false)
      end
    end

    describe 'pipeline_url' do
      it 'returns the last pipeline' do
        expect(client.pipeline_url).to eq('https://example.com/some/pipeline/url')
      end
    end
  end
end
