# frozen_string_literal: true

module WithoutDryRun
  # Unset the `TEST` environment variable that gets set by default
  def without_dry_run(&block)
    ClimateControl.modify(TEST: nil, &block)
  end
end

RSpec.configure do |config|
  config.include WithoutDryRun
end
