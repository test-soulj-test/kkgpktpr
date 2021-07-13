# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::UpdateGitalyMergeRequest do
  describe '#fresh?' do
    it 'returns true when recently created' do
      instance = described_class.new
      remote = double('Gitlab::ObjectifiedHash', created_at: Time.now.to_s)

      expect(instance).to receive(:exists?).and_return(true)
      expect(instance).to receive(:remote_issuable).and_return(remote)

      expect(instance).to be_fresh
    end

    it 'returns false when stale' do
      instance = described_class.new
      remote = double('Gitlab::ObjectifiedHash', created_at: 5.days.ago.to_s)

      expect(instance).to receive(:exists?).and_return(true)
      expect(instance).to receive(:remote_issuable).and_return(remote)

      expect(instance).not_to be_fresh
    end

    it 'returns false when not yet created' do
      instance = described_class.new

      expect(instance).to receive(:exists?).and_return(false)

      expect(instance).not_to be_fresh
    end
  end

  describe '#notifiable?' do
    it 'returns true when stale and not yet notified' do
      instance = described_class.new
      remote = double('Gitlab::ObjectifiedHash', labels: ['dependency update'])

      expect(instance).to receive(:exists?).and_return(true)
      expect(instance).to receive(:fresh?).and_return(false)
      expect(instance).to receive(:remote_issuable).and_return(remote)

      expect(instance).to be_notifiable
    end

    it 'returns false when already notified' do
      instance = described_class.new
      remote = double('Gitlab::ObjectifiedHash', labels: [described_class::NOTIFIED_LABEL])

      expect(instance).to receive(:exists?).and_return(true)
      expect(instance).to receive(:fresh?).and_return(false)
      expect(instance).to receive(:remote_issuable).and_return(remote)

      expect(instance).not_to be_notifiable
    end

    it 'returns false when fresh' do
      instance = described_class.new

      expect(instance).to receive(:exists?).and_return(true)
      expect(instance).to receive(:fresh?).and_return(true)

      expect(instance).not_to be_notifiable
    end

    it 'returns false when not yet created' do
      instance = described_class.new

      expect(instance).to receive(:exists?).and_return(false)

      expect(instance).not_to be_notifiable
    end
  end

  describe '#mark_as_stale' do
    it 'posts a comment on the merge request' do
      instance = described_class.new
      remote = double('Gitlab::ObjectifiedHash', project_id: 42, iid: 1)

      allow(instance).to receive(:remote_issuable).and_return(remote)

      expect(ReleaseTools::GitlabClient)
        .to receive(:create_merge_request_comment)
        .with(42, 1, a_string_including(%{/label ~"#{described_class::NOTIFIED_LABEL}"}))

      instance.mark_as_stale
    end
  end
end
