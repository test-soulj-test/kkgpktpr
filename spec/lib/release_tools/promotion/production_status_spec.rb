# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::ProductionStatus do
  subject(:status) { described_class.new }

  describe '.new' do
    it 'accepts extra checks' do
      extra_check = spy

      stub_const('ReleaseTools::Promotion::Checks::CustomCheck', extra_check)

      described_class.new(:custom_check)

      expect(extra_check).to have_received(:new)
    end

    it 'includes ActiveDeployments by default for backward compatibility' do
      status = described_class.new

      expect(status.checks.size).to eq(described_class::ALL_CHECKS.size + 1)
    end

    it 'excludes ActiveDeployments when requested for backward compatibility' do
      status = described_class.new(skip_active_deployment_check: true)

      expect(status.checks.size).to eq(described_class::ALL_CHECKS.size)
    end

    it 'raises InvalidCheckError for an invalid check' do
      expect { described_class.new(:invalid_check) }
        .to raise_error(described_class::InvalidCheckError)
    end
  end

  describe '#fine?' do
    it 'returns true when all checks are fine' do
      expect(status).to receive(:checks).and_return([
        double(fine?: true),
        double(fine?: true)
      ])

      expect(status).to be_fine
    end

    it 'returns false when any check is not fine' do
      expect(status).to receive(:checks).and_return([
        double(fine?: true),
        double(fine?: false),
        double(fine?: true)
      ])

      expect(status).not_to be_fine
    end
  end

  describe '#to_issue_body' do
    it 'returns the successful status check' do
      expect(status).to receive(:checks).and_return([
        double(fine?: true, to_issue_body: 'result check 1'),
        double(fine?: true, to_issue_body: 'result check 2')
      ]).twice

      text = status.to_issue_body

      expect(text).to match(%r{Production has no active ~severity::1 / ~severity::2 incidents})
    end
  end

  describe '#to_slack_blocks' do
    context 'when deployment is about to start' do
      context 'when it can start' do
        before do
          allow(status).to receive(:checks).and_return([
            double(fine?: true, to_slack_blocks: { text: 'result check 1' }),
            double(fine?: true, to_slack_blocks: { text: 'result check 2' })
          ])
        end

        it 'includes a success summary' do
          text = status.to_slack_blocks.first.dig(:text, :text)

          expect(text).to eq(':white_check_mark: Production checks pass! :shipit: :fine:')
        end

        it 'shows check blocks' do
          slack_blocks = status.to_slack_blocks

          expect(slack_blocks.length).to eq(1)
        end
      end

      context 'when checks are not fine' do
        before do
          allow(status).to receive(:checks).and_return([
            double(fine?: true, to_slack_blocks: { text: 'result check 1' }),
            double(fine?: false, to_slack_blocks: { text: 'result check 2' })
          ])
        end

        it 'includes a failure summary' do
          text = status.to_slack_blocks.first.dig(:text, :text)

          expect(text).to eq(':red_circle: Production checks fail!')
        end

        it 'shows check blocks' do
          slack_blocks = status.to_slack_blocks

          expect(slack_blocks.length).to eq(2)
          expect(slack_blocks[1][:text]).to eq('result check 2')
        end
      end
    end
  end
end
