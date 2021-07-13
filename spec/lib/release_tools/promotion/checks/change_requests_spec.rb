# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::Checks::ChangeRequests do
  let(:issues) { [] }

  subject(:check) { described_class.new }

  before do
    allow(ReleaseTools::GitlabClient).to receive(:issues).and_return(issues)
  end

  context 'when there are no issues on the production tracker' do
    describe '#fine?' do
      it { is_expected.to be_fine }
    end
  end

  context 'when there are C3 and C4 change issues on the production tracker' do
    let(:issues) do
      [
        double('C3', labels: %w(change::in-progress C3)),
        double('C4', labels: %w(change::in-progress C4))
      ]
    end

    describe '#fine?' do
      it { is_expected.to be_fine }
    end
  end

  context 'when there are C1 change issues on the production tracker' do
    let(:issues) do
      [
        double('C1', labels: %w(change::in-progress C1)),
        double('C4', labels: %w(change::in-progress C4))
      ]
    end

    describe '#fine?' do
      it { is_expected.not_to be_fine }
    end
  end

  context 'when there are C2 change issues on the production tracker' do
    let(:issues) do
      [
        double('C2', labels: %w(change::in-progress C2), title: 'Change1', url: 'https://change1'),
        double('C4', labels: %w(change::in-progress C4))
      ]
    end

    describe '#fine?' do
      it { is_expected.not_to be_fine }
    end
  end
end
