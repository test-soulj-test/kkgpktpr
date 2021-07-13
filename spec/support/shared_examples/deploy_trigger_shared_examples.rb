# frozen_string_literal: true

RSpec.shared_examples 'deploy trigger' do |ref, environment|
  let!(:fake_client) do
    stub_const('ReleaseTools::GitlabOpsClient', spy)
  end

  let(:deployer_project) { ReleaseTools::Project::Deployer }

  subject(:deploy) do
    described_class.new(environment: environment, ref: ref)
  end

  let(:pipeline_trigger) do
    double(
      :pipeline_trigger,
      id: 123,
      web_url: 'https://test.gitlab.com/gitlab-com/deployer/-/pipelines/123'
    )
  end

  before do
    fake_instance = double(:instance)

    allow(ReleaseTools::AutoDeploy::Tag)
      .to receive(:new)
      .and_return(fake_instance)

    allow(fake_instance)
      .to receive(:omnibus_package)
      .and_return('13.9.202102081220-19f7e30d4cf.3fc3c71e4fc')
  end

  after do
    FileUtils.rm_r('deploy_vars.env') if File.exist?('deploy_vars.env')
  end

  it "triggers the deployer to #{environment} using deployer #{ref} branch" do
    ClimateControl.modify(DEPLOYER_TRIGGER_TOKEN: 'token', CI_JOB_TOKEN: nil) do
      without_dry_run do
        allow(fake_client)
          .to receive(:run_trigger)
          .and_return(pipeline_trigger)

        expect(deploy.logger).to receive(:debug).and_call_original

        deploy.execute
      end

      expect(fake_client).to have_received(:run_trigger).with(
        deployer_project.ops_path,
        'token',
        ref,
        hash_including(
          'DEPLOY_ENVIRONMENT' => environment,
          'DEPLOY_USER' => 'deployer',
          'DEPLOY_VERSION' => '13.9.202102081220-19f7e30d4cf.3fc3c71e4fc',
          'SKIP_JOB_ON_COORDINATOR_PIPELINE' => 'true'
        )
      )
    end
  end

  it 'stores pipeline id into an env file' do
    ClimateControl.modify(DEPLOYER_TRIGGER_TOKEN: 'token', CI_JOB_TOKEN: nil) do
      without_dry_run do
        allow(fake_client)
          .to receive(:run_trigger)
          .and_return(pipeline_trigger)

        deploy.execute

        expect(File.read('deploy_vars.env'))
          .to eq("DEPLOY_PIPELINE_ID=#{pipeline_trigger.id}")
      end
    end
  end

  context 'with a dry-run' do
    it 'does not trigger a deployer pipeline' do
      ClimateControl.modify(DEPLOYER_TRIGGER_TOKEN: 'token', CI_JOB_TOKEN: nil) do
        deploy.execute

        expect(fake_client).not_to have_received(:run_trigger)
      end
    end
  end

  context 'when run_trigger throws an error' do
    it 'does not trigger a deployer pipeline' do
      expect do
        ClimateControl.modify(DEPLOYER_TRIGGER_TOKEN: 'token', CI_JOB_TOKEN: nil) do
          without_dry_run do
            allow(fake_client)
              .to receive(:run_trigger)
              .and_raise(gitlab_error(:InternalServerError))

            expect(deploy.logger).to receive(:fatal).and_call_original

            deploy.execute
          end
        end
      end.to raise_error(Gitlab::Error::InternalServerError)
    end
  end
end
