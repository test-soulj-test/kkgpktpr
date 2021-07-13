# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::ReleaseManagers::SyncResult do
  let(:error) { double('Error', message: 'Sync failed') }
  let(:client) { double('Client', target: :ops, sync_errors: [error]) }

  subject(:result) { described_class.new([client]) }

  describe '#formatted_error_message' do
    it 'returns the expected message' do
      msg = <<~MSG.strip
        --> Errors syncing to ops:
            Sync failed
      MSG

      expect(result.formatted_error_message).to eq(msg)
    end

    it 'returns an empty string if there were no errors' do
      allow(client).to receive(:sync_errors).and_return([])

      expect(result.formatted_error_message).to eq('')
    end
  end

  describe '#success?' do
    it 'is false when there are errors' do
      expect(result.success?).to be(false)
    end

    it 'is true when there are no errors' do
      allow(client).to receive(:sync_errors).and_return([])

      expect(result.success?).to be(true)
    end
  end
end
