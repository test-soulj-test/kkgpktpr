# frozen_string_literal: true

module FeatureStub
  def enable_all_features
    allow(ReleaseTools::Feature).to receive(:enabled?).and_return(true)
  end

  def disable_all_features
    allow(ReleaseTools::Feature).to receive(:enabled?).and_return(false)
  end

  def enable_feature(*args)
    allow(ReleaseTools::Feature).to receive(:enabled?).and_call_original

    args.each do |arg|
      allow(ReleaseTools::Feature)
        .to receive(:enabled?).with(arg.to_s).and_return(true)
      allow(ReleaseTools::Feature)
        .to receive(:enabled?).with(arg.to_sym).and_return(true)
    end
  end

  def disable_feature(*args)
    args.each do |arg|
      allow(ReleaseTools::Feature)
        .to receive(:enabled?).with(arg.to_s).and_return(false)
      allow(ReleaseTools::Feature)
        .to receive(:enabled?).with(arg.to_sym).and_return(false)
    end
  end
end

RSpec.configure do |config|
  config.include FeatureStub
end
