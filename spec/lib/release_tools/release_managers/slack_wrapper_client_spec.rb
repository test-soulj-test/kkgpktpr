# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::ReleaseManagers::SlackWrapperClient do
  let(:slack_wrapper_url)   { 'https://example.com' }
  let(:slack_wrapper_token) { 'my-secret-token' }

  subject(:client) do
    ClimateControl.modify(SLACK_WRAPPER_URL: slack_wrapper_url, SLACK_WRAPPER_TOKEN: slack_wrapper_token) do
      described_class.new
    end
  end

  describe 'initialize' do
    context 'when SLACK_WRAPPER_URL is not set' do
      let(:slack_wrapper_url) { nil }

      it 'raises an error' do
        expect { client }.to raise_error('Missing environment variable `SLACK_WRAPPER_URL`')
      end
    end

    context 'when SLACK_WRAPPER_TOKEN is not set' do
      let(:slack_wrapper_token) { nil }

      it 'raises an error' do
        expect { client }.to raise_error('Missing environment variable `SLACK_WRAPPER_TOKEN`')
      end
    end

    it { expect { client }.not_to raise_error }
  end

  describe '#sync_membership' do
    # Disable VCR for these requests, so that we can verify them with WebMock
    # without requiring a cassette recording
    around do |ex|
      VCR.turn_off!

      ex.run

      VCR.turn_on!
    end

    it 'sends a POST request with IDS and the provided token' do
      user_ids = %w[UID1 UID2 UID3]
      request = stub_request(:post, "#{slack_wrapper_url}/usergroups.users.update/#{ReleaseTools::Slack::RELEASE_MANAGERS}/UID1,UID2,UID3")
                  .with(headers: { Authorization: "Bearer #{slack_wrapper_token}" })

      client.sync_membership(user_ids)

      expect(request).to have_been_requested
    end

    context 'when the request is unauthorized' do
      it 'keeps track of the error' do
        request =
          stub_request(:post, "#{slack_wrapper_url}/usergroups.users.update/#{ReleaseTools::Slack::RELEASE_MANAGERS}/UID1")
            .to_return(status: 401)

        sync_error = ReleaseTools::ReleaseManagers::Client::UnauthorizedError.new('Unauthorized')

        client.sync_membership(%w[UID1])

        expect(request).to have_been_requested
        expect(subject.sync_errors).to contain_exactly(sync_error)
      end
    end

    context 'when the request is forbidden' do
      it 'keeps track of the error' do
        request =
          stub_request(:post, "#{slack_wrapper_url}/usergroups.users.update/#{ReleaseTools::Slack::RELEASE_MANAGERS}/UID1")
            .to_return(status: 403)

        sync_error = ReleaseTools::ReleaseManagers::Client::UnauthorizedError.new('Invalid token')

        client.sync_membership(%w[UID1])

        expect(request).to have_been_requested
        expect(subject.sync_errors).to contain_exactly(sync_error)
      end
    end

    context "with a Bad request (or any other failure)" do
      it 'keeps track of the error' do
        request =
          stub_request(:post, "#{slack_wrapper_url}/usergroups.users.update/#{ReleaseTools::Slack::RELEASE_MANAGERS}/UID1")
            .to_return(status: 400)

        sync_error = ReleaseTools::ReleaseManagers::Client::SyncError.new('Bad Request')

        client.sync_membership(%w[UID1])

        expect(request).to have_been_requested
        expect(subject.sync_errors).to contain_exactly(sync_error)
      end
    end
  end
end
