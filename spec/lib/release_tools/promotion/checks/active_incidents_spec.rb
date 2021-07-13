# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::Checks::ActiveIncidents do
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

  context 'when there is an active severity::1 incident on the production tracker' do
    let(:issues) { [double('incident', labels: %w(Incident::Active severity::1))] }

    describe '#fine?' do
      it { is_expected.not_to be_fine }
    end
  end

  context 'when there is an active severity::2 incident on the production tracker' do
    let(:issues) { [double('incident', labels: %w(Incident::Active severity::2))] }

    describe '#fine?' do
      it { is_expected.not_to be_fine }
    end
  end

  context 'when there is an active severity::3 incident on the production tracker' do
    let(:issues) { [double('incident', labels: %w(Incident::Active severity::3))] }

    describe '#fine?' do
      it { is_expected.to be_fine }
    end
  end

  context 'when there is an active severity::4 incident on the production tracker' do
    let(:issues) { [double('incident', labels: %w(Incident::Active severity::4))] }

    describe '#fine?' do
      it { is_expected.to be_fine }
    end
  end
end
