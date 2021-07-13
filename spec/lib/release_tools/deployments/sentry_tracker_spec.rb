# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Deployments::SentryTracker do
  subject(:tracker) { described_class.new }

  around do |ex|
    ClimateControl.modify(SENTRY_AUTH_TOKEN: 'token') do
      ex.run
    end
  end

  describe '#release' do
    let(:fake_client) { stub_const('HTTP', spy) }

    it 'creates a new release' do
      commit_id = '9bf75ddb8d878abc7f3cfb28718c391413bf5716'
      version   = '9bf75ddb8d8'

      expected_payload = {
        version: version,
        projects: %w[gitlabcom staginggitlabcom],
        refs: [
          {
            repository: 'GitLab.org / security / 🔒 gitlab',
            commit: commit_id
          }
        ]
      }

      expect(fake_client).to receive(:auth).with("Bearer token")
      expect(fake_client).to receive(:post).with(
        'https://sentry.gitlab.net/api/0/organizations/gitlab/releases/',
        json: expected_payload
      )

      without_dry_run do
        tracker.release(commit_id)
      end
    end

    it 'is idempotent' do
      version = '9bf75ddb8d8'

      expect(tracker).to receive(:new_release?)
        .with(version)
        .and_return(false)

      without_dry_run do
        expect(tracker.release(version)).to be_nil
      end
    end
  end

  describe '#deploy' do
    let(:fake_client) { stub_const('HTTP', spy) }

    it 'creates a new successful deploy' do
      version = '13.1.202006091440-ede0c8ff414.008fd19283c'
      environment = 'gprd-cny'

      Timecop.freeze do
        expected_payload = {
          environment: environment,
          dateStarted: Time.now.utc.iso8601,
          dateFinished: Time.now.utc.iso8601
        }

        expect(fake_client).to receive(:auth).with("Bearer token")
        expect(fake_client).to receive(:post).with(
          'https://sentry.gitlab.net/api/0/organizations/gitlab/releases/ede0c8ff414/deploys/',
          json: expected_payload
        )

        without_dry_run do
          tracker.deploy(environment, 'success', version)
        end
      end
    end

    it 'ignores unsuccessful deploys' do
      expect(fake_client).not_to receive(:post)

      without_dry_run do
        expect(tracker.deploy('gprd-cny', 'running', '1.2.3')).to be_nil
      end
    end
  end
end
