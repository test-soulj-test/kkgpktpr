# frozen_string_literal: true

require 'spec_helper'
require 'release_tools/tasks'
require 'release_tools/project/infrastructure/production'

describe ReleaseTools::Tasks::AutoDeploy::CheckProduction do
  let(:deploy_version) { '' }
  let(:chat_channel) { '' }
  let(:active_version) { ReleaseTools::Version.new('13.1') }
  let(:manager) { instance_double(ReleaseTools::Promotion::Manager) }
  let(:deployer_pipeline_url) { 'deployer-pipeline-url' }

  let(:now) { Time.local(2020, 2, 22, 16) }

  subject(:task) { described_class.new }

  before do
    schedule =
      instance_double(ReleaseTools::ReleaseManagers::Schedule,
                      active_version: active_version)

    allow(ReleaseTools::ReleaseManagers::Schedule).to receive(:new).and_return(schedule)

    allow(ReleaseTools::Promotion::Manager).to receive(:new).with(
      pipeline_url: deployer_pipeline_url,
      skip_active_deployment_check: false
    ).and_return(manager)
  end

  around do |example|
    ClimateControl.modify(DEPLOY_VERSION: deploy_version, CHAT_CHANNEL: chat_channel, DEPLOYER_PIPELINE_URL: deployer_pipeline_url, &example)
  end

  describe '#monthly_issue' do
    it 'returns the issue for the current milestone' do
      expect(ReleaseTools::MonthlyIssue).to receive(:new).with(version: active_version)

      task.monthly_issue
    end
  end

  context 'when triggered by the deployer' do
    let(:deploy_version) { '13.1.202005220540-7c84ccdc806.59f00bb0515' }

    it { is_expected.to be_authorize }
    it { is_expected.not_to be_chatops }

    context 'when DEPLOYMENT_CHECK is true' do
      let(:deploy_manager) { instance_double(ReleaseTools::Promotion::Manager) }
      let(:deployment_step) { 'gprd-cny-migrations' }
      let(:job_url) { 'https://test.net/deployer/-/jobs/123' }

      before do
        allow(ReleaseTools::Promotion::Manager).to receive(:new)
          .with(
            pipeline_url: deployer_pipeline_url,
            skip_active_deployment_check: true
          ).and_return(deploy_manager)
      end

      around do |example|
        ClimateControl.modify(
          DEPLOYMENT_CHECK: 'true',
          DEPLOYMENT_STEP: deployment_step,
          DEPLOYER_JOB_URL: job_url,
          &example
        )
      end

      it { is_expected.to be_deployment_check }
      it { is_expected.not_to be_authorize }
      it { is_expected.not_to be_chatops }

      it 'executes a deployment check' do
        expect(deploy_manager)
          .to receive(:deployment_check_report)
          .with(deploy_version, deployment_step, job_url)

        task.execute
      end
    end

    describe '#deploy_version' do
      it 'matches the environment variable' do
        expect(task.deploy_version).to eq(deploy_version)
      end
    end

    describe '#execute' do
      it 'will attempt to authorize a deployment' do
        expect(manager).to receive(:authorize!).with(
          ReleaseTools::Version.new(deploy_version),
          ReleaseTools::MonthlyIssue
        )

        expect(manager).not_to receive(:check_status)

        task.execute
      end
    end
  end

  context 'when triggered for a production issue update' do
    context 'with the default project' do
      around do |example|
        ClimateControl.modify(PRODUCTION_ISSUE_IID: '1234', &example)
      end

      describe '#execute' do
        it 'will create a production issue report' do
          expect(manager).to receive(:production_issue_report).with(
            project: ReleaseTools::Project::Infrastructure::Production,
            issue_iid: '1234'
          )
          task.execute
        end
      end
    end

    context 'with a project path override' do
      around do |example|
        ClimateControl.modify(
          PRODUCTION_ISSUE_IID: '1234',
          GITLAB_PRODUCTION_PROJECT_PATH: 'some/project/path',
          &example
        )
      end

      describe '#execute' do
        it 'will create a production issue report' do
          expect(manager).to receive(:production_issue_report).with(
            project: 'some/project/path',
            issue_iid: '1234'
          )
          task.execute
        end
      end
    end
  end

  context 'when triggered by chatops' do
    let(:chat_channel) { 'UG018231341' }

    it { is_expected.to be_chatops }
    it { is_expected.not_to be_authorize }

    describe '#chat_channel' do
      it 'matches the environment variable' do
        expect(task.slack_channel).to eq(chat_channel)
      end
    end

    describe '#execute' do
      it 'will publish the production status message on slack' do
        expect(manager).to receive(:check_status).with(
          chat_channel,
          raise_on_failure: false
        )
        expect(manager).not_to receive(:authorize!)

        task.execute
      end
    end

    context 'when triggered with SKIP_DEPLOYMENT_CHECK set ' do
      around do |example|
        ClimateControl.modify(SKIP_DEPLOYMENT_CHECK: 'true', &example)
      end

      before do
        allow(ReleaseTools::Promotion::Manager).to receive(:new)
          .with(
            pipeline_url: deployer_pipeline_url,
            skip_active_deployment_check: true
          ).and_return(manager)
      end

      describe '#execute' do
        it 'will publish the production status message on slack' do
          expect(manager).to receive(:check_status).with(
            chat_channel,
            raise_on_failure: false
          )
          task.execute
        end
      end
    end

    context 'when triggered with FAIL_IF_NOT_SAFE set ' do
      around do |example|
        ClimateControl.modify(FAIL_IF_NOT_SAFE: 'true', &example)
      end

      describe '#execute' do
        it 'will publish the production status message on slack' do
          expect(manager).to receive(:check_status).with(
            chat_channel,
            raise_on_failure: true
          )
          task.execute
        end
      end
    end
  end

  context 'when triggered by coordinator_pipeline' do
    let(:deploy_version) { '13.1.202005220540-7c84ccdc806.59f00bb0515' }
    let(:deployer_pipeline_url) { nil }
    let(:ci_pipeline_url) { 'ci-pipeline-url' }

    describe '#execute' do
      around do |example|
        ClimateControl.modify(
          DEPLOY_VERSION: deploy_version,
          CHAT_CHANNEL: chat_channel,
          DEPLOYER_PIPELINE_URL: deployer_pipeline_url,
          CI_PIPELINE_URL: ci_pipeline_url,
          &example
        )
      end

      it 'initializes manager with CI_PIPELINE_URL' do
        manager = double(:fake_manager, authorize?: true)

        allow(ReleaseTools::Promotion::Manager).to receive(:new)
          .with(pipeline_url: ci_pipeline_url, skip_active_deployment_check: false)
          .and_return(manager)

        expect(ReleaseTools::Promotion::Manager)
          .to receive(:new)
          .with(pipeline_url: ci_pipeline_url, skip_active_deployment_check: false)

        expect(manager).to receive(:authorize!)

        task.execute
      end
    end
  end

  describe '#deploy_version' do
    context 'when DEPLOY_VERSION is set' do
      let(:deploy_version) { '13.1.202005220540-7c84ccdc806.59f00bb0515' }

      it 'returns the env variable' do
        expect(task.deploy_version).to eq(deploy_version)
      end
    end

    context 'when DEPLOY_VERSION is not set' do
      let(:deploy_version) { nil }

      it 'returns the omnibus package' do
        fake_instance = double(:instance)
        omnibus_package = '13.1.202005220540-7c84ccdc806.59f00bb0515'

        allow(ReleaseTools::AutoDeploy::Tag)
          .to receive(:new)
          .and_return(fake_instance)

        allow(fake_instance)
          .to receive(:omnibus_package)
          .and_return(omnibus_package)

        expect(task.deploy_version).to eq(omnibus_package)
      end
    end
  end
end
