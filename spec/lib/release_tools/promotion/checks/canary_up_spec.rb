# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::Checks::CanaryUp do
  subject(:check) { described_class.new }

  def stub_prometheus(result)
    instance = instance_double('ReleaseTools::Prometheus::Query', run: result)

    stub_const('ReleaseTools::Prometheus::Query', double(new: instance))
  end

  context 'when canary is up' do
    before do
      stub_prometheus(
        {
          'status' => 'success',
          'data' => {
            'result' => []
          }
        }
      )
    end

    describe '#to_slack_blocks' do
      it 'shows a status message' do
        blocks = check.to_slack_blocks

        expect(blocks.length).to eq(1)
        expect(blocks.first.dig(:text, :text)).to include('Canary is up')
      end
    end

    describe '#to_issue_body' do
      it 'shows a status message' do
        body = check.to_issue_body

        expect(body).to include('Canary is up')
      end
    end
  end

  context 'when canary is down' do
    before do
      enable_feature(:check_canary_up)

      stub_prometheus(
        {
          'status' => 'success',
          'data' => {
            'resultType' => 'vector',
            'result' => [
              'metric' => {},
              'value' => [1_621_438_111.041, '42']
            ]
          }
        }
      )
    end

    describe '#to_slack_blocks' do
      it 'shows a status message' do
        blocks = check.to_slack_blocks

        expect(blocks.length).to eq(1)
        expect(blocks.first.dig(:text, :text)).to include('Canary is down')
      end
    end

    describe '#to_issue_body' do
      it 'shows a status message' do
        body = check.to_issue_body

        expect(body).to include('Canary is down')
      end
    end
  end
end
