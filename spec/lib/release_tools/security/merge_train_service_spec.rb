# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReleaseTools::Security::MergeTrainService do
  let!(:client) { stub_const('ReleaseTools::GitlabOpsClient', spy) }

  subject(:service) { described_class.new }

  def mirror_stub(overrides = {})
    defaults = {
      enabled: true,
      last_error: nil,
      update_status: 'finished',
      url: 'https://*****:*****@gitlab.com/gitlab-org/security/gitlab'
    }

    double(defaults.merge(overrides))
  end

  describe '#execute' do
    it "toggles on and notifies when required and inactive" do
      allow(service).to receive(:merge_train_required?).and_return(true)
      allow(service).to receive(:merge_train_active?).and_return(false)

      described_class::PROJECTS.each do |_, schedule_id|
        new_schedule = double

        expect(client).to receive(:edit_pipeline_schedule).with(
          ReleaseTools::Project::MergeTrain.path,
          schedule_id,
          active: true
        ).and_return(new_schedule)

        expect(ReleaseTools::Slack::MergeTrainNotification)
          .to receive(:toggled)
          .with(new_schedule)
      end

      service.execute
    end

    it "toggles off and notifies when not required and active" do
      allow(service).to receive(:merge_train_required?).and_return(false)
      allow(service).to receive(:merge_train_active?).and_return(true)

      described_class::PROJECTS.each do |_, schedule_id|
        new_schedule = double

        expect(client).to receive(:edit_pipeline_schedule).with(
          ReleaseTools::Project::MergeTrain.path,
          schedule_id,
          active: false
        ).and_return(new_schedule)

        expect(ReleaseTools::Slack::MergeTrainNotification)
          .to receive(:toggled)
          .with(new_schedule)
      end

      service.execute
    end

    it "does nothing when required and active" do
      allow(service).to receive(:merge_train_required?).and_return(true)
      allow(service).to receive(:merge_train_active?).and_return(true)

      expect(client).not_to receive(:edit_pipeline_schedule)

      service.execute
    end

    it "does nothing when not required and inactive" do
      allow(service).to receive(:merge_train_required?).and_return(false)
      allow(service).to receive(:merge_train_active?).and_return(false)

      expect(client).not_to receive(:edit_pipeline_schedule)

      service.execute
    end
  end

  describe '#merge_train_active?' do
    it "returns true when active" do
      expect(client).to receive(:pipeline_schedule)
        .and_return(double(active: true))

      expect(service.merge_train_active?(12_345)).to eq(true)
    end

    it "returns false when inactive" do
      expect(client).to receive(:pipeline_schedule)
        .and_return(double(active: false))

      expect(service.merge_train_active?(12_345)).to eq(false)
    end
  end

  describe '#merge_train_required?' do
    let!(:client) { stub_const('ReleaseTools::GitlabClient', spy) }

    it "returns true with an error on the subject branch" do
      project = ReleaseTools::Project::GitlabEe

      mirror = mirror_stub(last_error: "Some refs have diverged and have not been updated on the remote:\n\nrefs/heads/#{project.default_branch}")
      expect(client).to receive(:remote_mirrors).and_return([mirror])

      expect(service.merge_train_required?(project)).to eq(true)
    end

    it "returns false with unrelated errors" do
      project = ReleaseTools::Project::GitlabEe

      mirror = mirror_stub(last_error: "Some refs have diverged and have not been updated on the remote:\n\nrefs/heads/rs-master")
      expect(client).to receive(:remote_mirrors).and_return([mirror])

      expect(service.merge_train_required?(project)).to eq(false)
    end

    it "returns false with no errors" do
      mirror = mirror_stub
      expect(client).to receive(:remote_mirrors).and_return([mirror])

      expect(service.merge_train_required?('foo/bar')).to eq(false)
    end

    it "returns false and logs when security mirror can't be detected" do
      mirror = mirror_stub(url: 'https://example.com/invalid.git')
      expect(client).to receive(:remote_mirrors).and_return([mirror])

      expect(service.logger).to receive(:fatal).and_call_original

      expect(service.merge_train_required?('foo/bar')).to eq(false)
    end

    it "returns false and logs when encountering an unknown error" do
      expect(client).to receive(:remote_mirrors)
        .and_raise(gitlab_error(:BadRequest))

      expect(service.merge_train_required?('foo/bar')).to eq(false)
    end
  end
end
