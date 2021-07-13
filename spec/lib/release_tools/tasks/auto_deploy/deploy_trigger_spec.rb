# frozen_string_literal: true

require 'spec_helper'
require 'release_tools/tasks'

RSpec.describe ReleaseTools::Tasks::AutoDeploy::DeployTrigger do
  subject(:deploy) { described_class.new }

  context 'when deploying to all environments' do
    it_behaves_like 'deploy trigger', 'master', 'gstg,gprd-cny,gprd'
  end

  context 'when deploying to staging' do
    it_behaves_like 'deploy trigger', 'next_gen', 'gstg'
  end

  context 'when deploying to canary' do
    it_behaves_like 'deploy trigger', 'next_gen', 'cny'
  end
end
