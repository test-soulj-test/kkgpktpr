# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Qa::IssuableSortByLabels do
  let(:team_labels) { %w[Team1 Team2 Team3] }
  let(:type_labels) { %w[TypeA TypeB TypeC] }

  let(:mr1) { double("id": 1, "labels" => %w[Team1 TypeA]) }
  let(:mr2) { double("id": 2, "labels" => %w[Team2 TypeB]) }
  let(:mr3) { double("id": 3, "labels" => %w[Team1 TypeC]) }
  let(:mr4) { double("id": 4, "labels" => %w[Team3 TypeA]) }
  let(:mr5) { double("id": 5, "labels" => %w[Team2 WithoutType]) }
  let(:mr6) { double("id": 6, "labels" => %w[WithoutTeam TypeC]) }
  let(:mr7) { double("id": 7, "labels" => %w[Team1 TypeA]) }

  let(:issuables) { [mr1, mr2, mr3, mr4, mr5, mr6, mr7] }

  subject { described_class.new(issuables).sort_by_labels(*labels) }

  describe '#sort_by_labels' do
    context 'single array' do
      let(:labels) { [team_labels] }

      it 'sorts by one label' do
        expect(subject["Team1"]).to eq([mr1, mr3, mr7])
        expect(subject["Team2"]).to eq([mr2, mr5])
        expect(subject["Team3"]).to eq([mr4])
        expect(subject["uncategorized"]).to eq([mr6])
      end
    end

    context 'multiple arrays' do
      let(:labels) { [team_labels, type_labels] }

      it 'sorts by all labels' do
        expect(subject["Team1"]["TypeA"]).to eq([mr1, mr7])
        expect(subject["Team1"]["TypeC"]).to eq([mr3])
        expect(subject["Team2"]["TypeB"]).to eq([mr2])
        expect(subject["Team2"]["uncategorized"]).to eq([mr5])
        expect(subject["Team3"]["TypeA"]).to eq([mr4])
        expect(subject["uncategorized"]).to eq([mr6])
      end
    end

    context 'unmatched category' do
      let(:unmatched_category) { "Team4" }
      let(:labels) { [team_labels << unmatched_category] }

      it 'does not add an empty array' do
        expect(subject[unmatched_category]).to be_nil
      end
    end
  end
end
