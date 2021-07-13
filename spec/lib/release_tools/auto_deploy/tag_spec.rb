# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReleaseTools::AutoDeploy::Tag do
  describe '.current' do
    context 'with a manually-specified tag' do
      it 'returns the specified tag' do
        ClimateControl.modify(AUTO_DEPLOY_TAG: 'auto-deploy-tag', CI_COMMIT_TAG: 'some-tag') do
          expect(described_class.current).to eq('auto-deploy-tag')
        end
      end
    end

    context 'in a tagged pipeline' do
      it 'returns the current tag' do
        ClimateControl.modify(AUTO_DEPLOY_TAG: nil, CI_COMMIT_TAG: 'some-tag') do
          expect(described_class.current).to eq('some-tag')
        end
      end
    end

    context 'in an untagged pipeline' do
      it 'builds the tag from the current auto-deploy branch' do
        env = {
          AUTO_DEPLOY_TAG: nil,
          CI_COMMIT_TAG: nil,
          AUTO_DEPLOY_BRANCH: '1-2-auto-deploy'
        }

        ClimateControl.modify(env) do
          Timecop.freeze(Time.new(2015, 1, 2, 3, 4, 0, 'UTC')) do
            # Even though we're freezing time here, the `NOW` constant was
            # already defined as soon as we ran `rspec`.
            #
            # As a workaround, stub the constant to our new current time, which
            # is actually the past. Great Scott!
            stub_const("#{described_class}::NOW", Time.now.utc)
          end

          expect(described_class.current).to eq('1.2.201501020304')
        end
      end
    end
  end

  describe '#component_ref' do
    it 'returns the specific component ref' do
      test_ref = '123'

      metadata = {
        'releases' => {
          'test' => {
            'ref' => test_ref
          }
        }
      }

      ClimateControl.modify(AUTO_DEPLOY_BRANCH: '1-2-auto-deploy') do
        tag = described_class.new

        allow(tag).to receive(:release_metadata)
          .and_return(metadata)

        ref = tag.component_ref(component: 'test')

        expect(ref).to eq(test_ref)
      end
    end
  end

  describe '#omnibus_package' do
    it 'returns the omnibus package' do
      omnibus_ref = '13.11.202103300420+08d97919f95.b031a4c4d63'

      metadata = {
        'releases' => {
          'omnibus-gitlab-ee' => {
            'ref' => omnibus_ref
          }
        }
      }

      ClimateControl.modify(AUTO_DEPLOY_BRANCH: '1-2-auto-deploy') do
        tag = described_class.new

        allow(tag).to receive(:release_metadata)
          .and_return(metadata)

        expect(tag.omnibus_package).to eq('13.11.202103300420-08d97919f95.b031a4c4d63')
      end
    end
  end

  describe '#release_metadata' do
    let(:metadata) do
      {
        'releases' => {
          'test_component' => {
            'ref' => 'test_ref'
          }
        }
      }
    end

    context 'when using AUTO_DEPLOY environment variable' do
      it 'returns metadata from the specific version' do
        ClimateControl.modify(AUTO_DEPLOY_BRANCH: '1-2-auto-deploy') do
          fake_client = stub_const('ReleaseTools::GitlabOpsClient', spy)

          allow(fake_client)
            .to receive(:release_metadata)
            .and_return(metadata)

          tag = described_class.new

          expect(tag.release_metadata).to eq(metadata)
        end
      end
    end
  end
end
