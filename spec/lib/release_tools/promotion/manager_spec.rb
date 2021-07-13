# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Promotion::Manager do
  let(:deploy_package) { '13.1.202005220540-7c84ccdc806.59f00bb0515' }
  let(:package_version) { ReleaseTools::Version.new(deploy_package) }
  let(:version) { ReleaseTools::Version.new('13.1.0') }
  let(:status) { instance_double(ReleaseTools::Promotion::ProductionStatus, fine?: true) }
  let(:pipeline_url) { 'http://example.com' }

  subject(:manager) do
    described_class.new(pipeline_url: pipeline_url)
  end

  before do
    allow(ReleaseTools::ReleaseManagers::Schedule)
      .to receive(:new)
      .and_return(instance_double(ReleaseTools::ReleaseManagers::Schedule, version_for_date: version))

    allow(manager).to receive(:status).and_return(status)
  end

  describe '#release_manager' do
    subject(:release_manager) { manager.send(:release_manager) }

    it 'reads the username from RELEASE_MANAGER env variable' do
      definitions = double('Definitions')
      allow(ReleaseTools::ReleaseManagers::Definitions).to receive(:new).and_return(definitions)
      expect(definitions).to receive(:find_user)
        .with('ops_username', instance: :ops)
        .and_return(double('User', production: 'username'))

      ClimateControl.modify(RELEASE_MANAGER: 'ops_username') do
        expect(release_manager).to eq('@username')
      end
    end

    it 'tracks unknown release managers' do
      ClimateControl.modify(RELEASE_MANAGER: 'ops-unknown') do
        expect(release_manager).to eq(":warning: Unknown release manager! OPS username ops-unknown")
      end
    end
  end

  describe '#authorize!' do
    let(:fake_client) { spy("ReleaseTools::GitlabClient") }
    let(:issue) { instance_double(ReleaseTools::MonthlyIssue, project: ReleaseTools::Project::Release::Tasks) }

    before do
      stub_const("ReleaseTools::GitlabClient", fake_client)
    end

    it 'updates the issue' do
      expect(manager).to receive(:release_manager).and_return('@a-user')

      expect(ReleaseTools::Promotion::StatusNote).to receive(:new)
        .with(
          status: status,
          package_version: package_version,
          ci_pipeline_url: pipeline_url,
          release_manager: '@a-user',
          override_status: false,
          override_reason: 'false'
        ).and_return(double('note', body: 'a comment'))

      without_dry_run do
        manager.authorize!(package_version, issue)
      end

      expect(fake_client)
        .to have_received(:create_issue_note)
        .with(
          ReleaseTools::Project::Release::Tasks,
          issue: issue,
          body: 'a comment'
        )
    end

    it 'raises an exception if the system is not fine' do
      expect(status).to receive(:fine?).and_return(false)
      expect(manager).to receive(:create_issue_comment)

      without_dry_run do
        expect { manager.authorize!(package_version, issue) }.to raise_error(ReleaseTools::Promotion::Manager::UnsafeProductionError)
      end
    end

    context 'when IGNORE_PRODUCTION_CHECKS is set' do
      it 'updates the issue with the reason why it was overridden' do
        ignore_production_checks = 'a reason to ignore checks'

        expect(manager).to receive(:release_manager).and_return('@a-user')

        expect(ReleaseTools::Promotion::StatusNote).to receive(:new)
          .with(
            status: status,
            package_version: package_version,
            ci_pipeline_url: pipeline_url,
            release_manager: '@a-user',
            override_status: true,
            override_reason: ignore_production_checks
          ).and_return(double('note', body: 'a comment'))

        ClimateControl.modify(
          IGNORE_PRODUCTION_CHECKS: ignore_production_checks
        ) do
          without_dry_run do
            manager.authorize!(package_version, issue)
          end
        end

        expect(fake_client)
          .to have_received(:create_issue_note)
          .with(
            ReleaseTools::Project::Release::Tasks,
            issue: issue,
            body: 'a comment'
          )
      end

      it 'unescapes the ignore reason' do
        expect(manager).to receive(:release_manager).and_return('@a-user')

        expect(ReleaseTools::Promotion::StatusNote).to receive(:new)
          .with(
            status: status,
            package_version: package_version,
            ci_pipeline_url: pipeline_url,
            release_manager: '@a-user',
            override_status: true,
            override_reason: 'foo,bar'
          ).and_return(double('note', body: 'a comment'))

        ClimateControl.modify(
          IGNORE_PRODUCTION_CHECKS: CGI.escape('foo,bar')
        ) do
          without_dry_run do
            manager.authorize!(package_version, issue)
          end
        end

        expect(fake_client)
          .to have_received(:create_issue_note)
          .with(
            ReleaseTools::Project::Release::Tasks,
            issue: issue,
            body: 'a comment'
          )
      end

      it "doesn't raise an exception if the system is not fine" do
        ignore_production_checks = 'a reason to ignore checks'

        expect(manager).to receive(:create_issue_comment)

        ClimateControl.modify(IGNORE_PRODUCTION_CHECKS: ignore_production_checks) do
          without_dry_run do
            expect { manager.authorize!(package_version, issue) }.not_to raise_error
          end
        end
      end
    end
  end

  describe '#check_status' do
    let(:channel) { double('channel id') }
    let(:slack_msg) { double('message') }

    before do
      stub_const('ReleaseTools::Promotion::ProductionStatus', double(new: status))
    end

    context 'Without raise_on_failure' do
      it 'post a message on slack' do
        expect(status).to receive(:to_slack_blocks).and_return(slack_msg)

        expect(ReleaseTools::Slack::ChatopsNotification)
          .to receive(:fire_hook)
          .with(channel: channel, blocks: slack_msg)

        without_dry_run do
          manager.check_status(channel)
        end
      end
    end

    context 'With raise_on_failure' do
      let(:status) { double(:status, fine?: fine) }

      before do
        allow(manager).to receive(:status).and_return(status)
      end

      context 'if feature flag checks fail' do
        let(:fine) { false }

        it 'post a message on slack' do
          expect(status).to receive(:to_slack_blocks).and_return(slack_msg)
          expect { manager.check_status(channel, raise_on_failure: true) }.to raise_error(
            ReleaseTools::Promotion::Manager::UnsafeProductionError
          )
        end
      end

      context 'if feature flag checks pass' do
        let(:fine) { true }

        it 'post a message on slack' do
          expect(status).to receive(:to_slack_blocks).and_return(slack_msg)

          expect(ReleaseTools::Slack::ChatopsNotification)
            .to receive(:fire_hook)
            .with(channel: channel, blocks: slack_msg)

          without_dry_run do
            manager.check_status(channel, raise_on_failure: true)
          end
        end
      end
    end
  end

  describe '#production_issue_report' do
    let(:status) { double(to_issue_body: 'issue update') }

    before do
      allow(manager).to receive(:status).and_return(status)
    end

    context 'with a valid issue iid' do
      it 'creates a note on a production issue' do
        issue = double(:issue, web_url: 'foo', labels: [])

        expect(ReleaseTools::GitlabClient)
          .to receive(:issue)
          .with(
            'some/project',
            '1234'
          )
          .and_return(Gitlab::PaginatedResponse.new(issue))

        expect(ReleaseTools::GitlabClient)
          .to receive(:create_issue_note)
          .with(
            'some/project',
            issue: issue,
            body: 'issue update'
          )

        manager.production_issue_report(
          project: 'some/project',
          issue_iid: '1234'
        )
      end
    end

    context 'with an invalid issue iid' do
      it 'raises an exception' do
        expect(ReleaseTools::GitlabClient)
          .to receive(:issue).exactly(3).times
          .and_raise(gitlab_error(:NotFound, code: 404))

        expect(ReleaseTools::GitlabClient)
          .not_to receive(:create_issue_note)

        expect do
          manager.production_issue_report(
            project: 'some/project',
            issue_iid: '1234'
          )
        end.to raise_error(RuntimeError, /Unable to find issue/)
      end
    end
  end

  describe '#deployment_check_report' do
    let(:deployment_step) { 'gprd-cny-migrations' }
    let(:deployment_job_url) { 'https://test.net/deployer/-/jobs/123' }
    let(:status) { double(:status, fine?: false) }

    it 'executes the deployment check report' do
      deployment_check_report = instance_double(
        ReleaseTools::Promotion::DeploymentCheckReport
      )

      deployment_foreword = instance_double(
        ReleaseTools::Promotion::DeploymentCheckForeword,
        to_slack_block: double('deployment_foreword')
      )

      expect(ReleaseTools::Promotion::DeploymentCheckForeword)
        .to receive(:new)
        .with(package_version, deployment_step, deployment_job_url)
        .and_return(deployment_foreword)

      allow(ReleaseTools::Promotion::DeploymentCheckReport)
        .to receive(:new)
        .and_return(deployment_check_report)

      expect(deployment_check_report).to receive(:execute)

      manager.deployment_check_report(package_version, deployment_step, deployment_job_url)
    end
  end
end
