# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Issuable do
  # rubocop:disable RSpec/LeakyConstantDeclaration,Lint/ConstantDefinitionInBlock
  # NOTE: We can't use an anonymous class in a `let` definition because we're
  # testing `#type`, which won't behave as expected in an anonymous class.
  class TestIssuable < ReleaseTools::Issuable
    protected

    def template
      "<%= RUBY_VERSION %>"
    end
  end
  # rubocop:enable RSpec/LeakyConstantDeclaration,Lint/ConstantDefinitionInBlock

  subject { TestIssuable.new }

  describe '#type' do
    it { expect(subject.type).to eq 'Test Issuable' }
  end

  describe '#description' do
    it { expect(subject.description).to eq RUBY_VERSION }
  end

  describe '#project' do
    it 'returns ReleaseTools::Project::GitlabEe by default' do
      expect(subject.project).to eq(ReleaseTools::Project::GitlabEe)
    end

    context 'when a project is set' do
      subject { described_class.new(project: ReleaseTools::Project::OmnibusGitlab) }

      it 'returns the given project' do
        expect(subject.project).to eq(ReleaseTools::Project::OmnibusGitlab)
      end
    end
  end

  describe '#iid' do
    it 'delegates to remote_issuable' do
      remote_issuable = double(iid: 1234)
      allow(subject).to receive(:remote_issuable).and_return(remote_issuable)

      expect(subject.iid).to eq(1234)
    end
  end

  describe '#created_at' do
    context 'when passed a String' do
      it 'returns a Time' do
        expect(TestIssuable.new(created_at: '2018-01-01').created_at).to eq(Time.new(2018, 1, 1))
      end
    end

    context 'when passed a Time' do
      it 'returns a Time' do
        expect(TestIssuable.new(created_at: Time.new(2018, 1, 1)).created_at).to eq(Time.new(2018, 1, 1))
      end
    end
  end

  describe '#exists?' do
    context 'when remote subject does not exist' do
      before do
        allow(subject).to receive(:remote_issuable).and_return(nil)
      end

      it { is_expected.not_to be_exists }
    end

    context 'when remote subject exists' do
      before do
        allow(subject).to receive(:remote_issuable).and_return(double)
      end

      it { is_expected.to be_exists }
    end
  end

  describe '#create' do
    it { expect { subject.create }.to raise_error(NotImplementedError) }
  end

  describe '#remote_issuable' do
    it { expect { subject.remote_issuable }.to raise_error(NotImplementedError) }
  end

  describe '#url' do
    it { expect { subject.url }.to raise_error(NotImplementedError) }
  end

  describe '#create?' do
    it { expect(subject.create?).to eq(true) }
  end
end
