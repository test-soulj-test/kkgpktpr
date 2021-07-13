# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::ReleaseManagers::Client do
  describe 'initialize' do
    # Disable VCR for these requests, so that we can verify them with WebMock
    # without requiring a cassette recording
    around do |ex|
      VCR.turn_off!

      ex.run

      VCR.turn_on!
    end

    it 'configures properly for dev' do
      request = stub_request(:get, %r{\Ahttps://dev\.gitlab\.org/.+})

      described_class.new(:dev).members

      expect(request).to have_been_requested
    end

    it 'configures properly for production' do
      request = stub_request(:get, %r{\Ahttps://gitlab\.com/.+})

      described_class.new(:production).members

      expect(request).to have_been_requested
    end

    it 'configures properly for ops' do
      request = stub_request(:get, %r{\Ahttps://ops\.gitlab\.net/.+})

      described_class.new(:ops).members

      expect(request).to have_been_requested
    end
  end

  describe '#sync_membership' do
    subject { described_class.new(:dev) }

    let(:internal_client) do
      spy(
        group_members: [
          double(username: 'james'),
          double(username: 'RSPEICHER') # Test case-sensitivity
        ]
      )
    end

    before do
      allow(subject).to receive(:client).and_return(internal_client)
    end

    it 'adds missing members, skipping existing members' do
      expect(subject).to receive(:add_member).with('douwem')
      expect(subject).not_to receive(:add_member).with('james')
      expect(subject).not_to receive(:add_member).with('rspeicher')

      subject.sync_membership(%w[DouweM james rspeicher])
    end

    it 'removes undefined members, skipping existing members' do
      expect(subject).to receive(:remove_member).with('rspeicher')
      expect(subject).not_to receive(:remove_member).with('james')

      subject.sync_membership(%w[james])
    end

    it 'keeps track of exceptions when they occur' do
      sync_error = ReleaseTools::ReleaseManagers::Client::SyncError.new('BOOM')
      expect(subject).to receive(:get_user) { raise sync_error }

      expect { subject.sync_membership(%w[james]) }.not_to raise_error
      expect(subject.sync_errors).to contain_exactly(sync_error)
    end
  end

  describe '#get_user' do
    subject { described_class.new(:dev) }

    let(:internal_client) { double('Client') }

    before do
      allow(subject).to receive(:client).and_return(internal_client)
    end

    it 'searches users by username' do
      expect(internal_client)
        .to receive(:users)
        .with(username: 'bob')
        .and_return([double(username: 'bob')])

      expect(subject.get_user('bob').username).to eq 'bob'
    end

    it 'raises an error when a user was not found' do
      expect(internal_client)
        .to receive(:users)
        .with(username: 'bob')
        .and_return([])

      expect { subject.get_user('bob') }.to raise_error(ReleaseTools::ReleaseManagers::Client::UserNotFoundError)
    end
  end
end
