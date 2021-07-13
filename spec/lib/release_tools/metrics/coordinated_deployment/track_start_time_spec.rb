# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Metrics::CoordinatedDeployment::TrackStartTime do
  subject(:metric) { described_class.new }

  describe '#execute' do
    after do
      FileUtils.rm_r('deploy_vars.env') if File.exist?('deploy_vars.env')
    end

    it 'appends the start time to_deploy_vars' do
      enable_feature(:measure_deployment_duration)

      local_time = Time.parse('2021-06-11 00:00:01.0000 UTC')

      file_content = <<~CONTENT.strip
        DEPLOY_START_TIME='#{local_time}'
      CONTENT

      Timecop.freeze(local_time) do
        metric.execute
      end

      expect(File.read('deploy_vars.env')).to eq(file_content)
    end

    context 'with measure_deployment_duration disabled' do
      it 'does not modify deploy_vars.env file' do
        disable_feature(:measure_deployment_duration)

        metric.execute

        expect(File).not_to exist('deploy_vars.env')
      end
    end
  end
end
