# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Deployments::DeploymentTracker do
  describe '#qa_commit_range' do
    let(:version) { '12.7.202001101501-94b8fd8d152.6fea3031ec9' }

    context 'when deploying failed' do
      it 'returns an empty Array' do
        tracker = described_class.new('gstg', 'failed', version)

        expect(tracker.qa_commit_range).to be_empty
      end
    end

    context 'when deploying to a QA environment with deployments' do
      it 'returns the current and previous deployment SHAs' do
        tracker = described_class.new('gstg', 'success', version)

        allow(ReleaseTools::GitlabClient)
          .to receive(:deployments)
          .and_return([
            double(:deployment, sha: 'bar'),
            double(:deployment, sha: 'foo')
          ])

        expect(tracker.qa_commit_range).to eq(%w[foo bar])
      end
    end

    context 'when deploying to a QA environment with for the first time' do
      it 'does not return the previous deployment SHA' do
        tracker = described_class.new('gstg', 'success', version)

        allow(ReleaseTools::GitlabClient)
          .to receive(:deployments)
          .and_return([double(:deployment, sha: 'foo')])

        expect(tracker.qa_commit_range).to eq([nil, 'foo'])
      end
    end

    context 'when deploying to a non-QA environment' do
      it 'returns an empty Array' do
        tracker = described_class.new('foo', 'success', version)

        allow(ReleaseTools::GitlabClient)
          .to receive(:deployments)
          .and_return([])

        expect(tracker.qa_commit_range).to be_empty
      end
    end
  end

  describe '#track' do
    # Simulate a `Gitlab::ObjectifiedHash` for a `update_or_create_deployment` response
    def deployment_stub(id:, iid: id, ref: 'master', sha: '123', status: 'success')
      double(:deployment, id: id, iid: iid, ref: ref, sha: sha, status: status)
    end

    # Stub a `file_contents` response for `GITALY_SERVER_VERSION`
    def stub_gitaly_server_version(contents)
      allow(ReleaseTools::GitlabClient)
        .to receive(:file_contents)
        .with(anything, 'GITALY_SERVER_VERSION', anything)
        .and_return(contents)
    end

    context 'when using a valid status' do
      let(:version) { '12.7.202001101501-94b8fd8d152.6fea3031ec9' }
      let(:parser) do
        instance_double(ReleaseTools::Deployments::DeploymentVersionParser)
      end
      let(:omnibus_parser) do
        instance_double(ReleaseTools::Deployments::OmnibusDeploymentVersionParser)
      end

      let(:parsed_version) do
        ReleaseTools::Deployments::DeploymentVersionParser::DeploymentVersion
          .new('123', '1-2-auto-deploy-01022020', false)
      end
      let(:parsed_omnibus_version) do
        ReleaseTools::Deployments::OmnibusDeploymentVersionParser::DeploymentVersion
          .new('456', '1-2-auto-deploy-01022020', false)
      end

      before do
        allow(parser)
          .to receive(:parse)
          .with(version)
          .and_return(parsed_version)

        allow(ReleaseTools::Deployments::DeploymentVersionParser)
          .to receive(:new)
          .and_return(parser)

        allow(omnibus_parser)
          .to receive(:parse)
          .with(version)
          .and_return(parsed_omnibus_version)

        allow(ReleaseTools::Deployments::OmnibusDeploymentVersionParser)
          .to receive(:new)
          .and_return(omnibus_parser)

        # We test the logging of previous deployments separately.
        allow(ReleaseTools::GitlabClient)
          .to receive(:deployments)
          .and_return(Gitlab::PaginatedResponse.new([]))
      end

      it 'tracks the deployment of GitLab, Gitaly, and Omnibus GitLab in 2 repositories' do
        stub_gitaly_server_version('94b8fd8d152680445ec14241f14d1e4c04b0b5ab')

        tracker = described_class.new('staging', 'running', version)
        allow(tracker).to receive(:log_previous_deployment)

        # Verify the Security deploys on the auto-deploy branch

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::GitlabEe.auto_deploy_path,
            'staging',
            ref: '1-2-auto-deploy-01022020',
            sha: '123',
            status: 'running',
            tag: false
          )
          .and_return(deployment_stub(id: 1, sha: '123'))

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::Gitaly.auto_deploy_path,
            'staging',
            ref: 'master', # Gitaly will always use `master`
            sha: '94b8fd8d152680445ec14241f14d1e4c04b0b5ab',
            status: 'running',
            tag: false
          )
          .and_return(deployment_stub(id: 2, sha: '94b8fd8d152680445ec14241f14d1e4c04b0b5ab'))

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::OmnibusGitlab.auto_deploy_path,
            'staging',
            ref: '1-2-auto-deploy-01022020',
            sha: '456',
            status: 'running',
            tag: false
          )
          .and_return(deployment_stub(id: 3, sha: '456'))

        # Verify the Canonical deploys on the `master` branch

        expect(tracker).to receive(:auto_deploy_intersection)
          .with(ReleaseTools::Project::GitlabEe, '123')
          .and_return('abcde')

        expect(tracker).to receive(:auto_deploy_intersection)
          .with(ReleaseTools::Project::Gitaly, '94b8fd8d152680445ec14241f14d1e4c04b0b5ab')
          .and_return('94b8fd8d152680445ec14241f14d1e4c04b0b5ab')

        expect(tracker).to receive(:auto_deploy_intersection)
          .with(ReleaseTools::Project::OmnibusGitlab, '456')
          .and_return('fghij')

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::GitlabEe.path,
            'staging',
            ref: 'master',
            sha: 'abcde',
            status: 'running',
            tag: false
          )
          .and_return(deployment_stub(id: 4, sha: 'abcde'))

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::Gitaly.path,
            'staging',
            ref: 'master',
            sha: '94b8fd8d152680445ec14241f14d1e4c04b0b5ab',
            status: 'running',
            tag: false
          )
          .and_return(deployment_stub(id: 5, sha: '94b8fd8d152680445ec14241f14d1e4c04b0b5ab'))

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::OmnibusGitlab.path,
            'staging',
            ref: 'master',
            sha: 'fghij',
            status: 'running',
            tag: false
          )
          .and_return(deployment_stub(id: 6, sha: 'fghij'))

        deployments = tracker.track

        expect(deployments.length).to eq(6)
        expect(deployments.collect(&:id)).to match_array([1, 2, 3, 4, 5, 6])
        expect(deployments.collect(&:project_path)).to include(
          ReleaseTools::Project::GitlabEe.auto_deploy_path,
          ReleaseTools::Project::GitlabEe.path
        )
      end

      it 'does not create a canonical deployment when no canonical commit is found' do
        tracker = described_class.new('staging', 'success', version)

        stub_gitaly_server_version('94b8fd8d152680445ec14241f14d1e4c04b0b5ab')

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::GitlabEe.auto_deploy_path,
            'staging',
            ref: '1-2-auto-deploy-01022020',
            sha: '123',
            status: 'success',
            tag: false
          )
          .and_return(deployment_stub(id: 1, sha: '123'))

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::Gitaly.auto_deploy_path,
            'staging',
            ref: 'master', # Gitaly will always use `master`
            sha: '94b8fd8d152680445ec14241f14d1e4c04b0b5ab',
            status: 'success',
            tag: false
          )
          .and_return(deployment_stub(id: 2, sha: '94b8fd8d152680445ec14241f14d1e4c04b0b5ab'))

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::OmnibusGitlab.auto_deploy_path,
            'staging',
            ref: '1-2-auto-deploy-01022020',
            sha: '456',
            status: 'success',
            tag: false
          )
          .and_return(deployment_stub(id: 3, sha: '456'))

        expect(tracker).to receive(:auto_deploy_intersection)
          .and_return(nil)
          .thrice

        deployments = tracker.track

        expect(deployments.length).to eq(3)
        expect(deployments.collect(&:id)).to contain_exactly(1, 2, 3)
      end

      it 'tracks the Gitaly deployment when Gitaly uses a tag version' do
        tracker = described_class.new('staging', 'success', version)

        # We're only concerned with Gitaly deployments here, so stub the others
        allow(tracker).to receive(:track_gitlab_deployments).and_return([])
        allow(tracker).to receive(:track_omnibus_deployments).and_return([])
        allow(tracker).to receive(:auto_deploy_intersection).and_return(nil)

        stub_gitaly_server_version('1.2.3')

        expect(ReleaseTools::GitlabClient)
          .to receive(:tag)
          .with(
            ReleaseTools::Project::Gitaly.auto_deploy_path,
            tag: 'v1.2.3'
          )
          .and_return(
            double(:tag, name: 'v1.2.3', commit: double(:commit, id: 'abc'))
          )

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::Gitaly.auto_deploy_path,
            'staging',
            ref: 'v1.2.3',
            sha: 'abc',
            status: 'success',
            tag: true
          )
          .and_return(deployment_stub(id: 2, sha: 'abc'))

        deployments = tracker.track

        expect(deployments.length).to eq(1)
        expect(deployments[0].id).to eq(2)
      end

      it 'tracks the Gitaly deployment when Gitaly uses an RC tag version' do
        tracker = described_class.new('staging', 'success', version)

        # We're only concerned with Gitaly deployments here, so stub the others
        allow(tracker).to receive(:track_gitlab_deployments).and_return([])
        allow(tracker).to receive(:track_omnibus_deployments).and_return([])
        allow(tracker).to receive(:auto_deploy_intersection).and_return(nil)

        stub_gitaly_server_version('1.2.3-rc1')

        expect(ReleaseTools::GitlabClient)
          .to receive(:tag)
          .with(
            ReleaseTools::Project::Gitaly.auto_deploy_path,
            tag: 'v1.2.3-rc1'
          )
          .and_return(
            double(:tag, name: 'v1.2.3-rc1', commit: double(:commit, id: 'abc'))
          )

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::Gitaly.auto_deploy_path,
            'staging',
            ref: 'v1.2.3-rc1',
            sha: 'abc',
            status: 'success',
            tag: true
          )
          .and_return(deployment_stub(id: 2, sha: 'abc'))

        deployments = tracker.track

        expect(deployments.length).to eq(1)
        expect(deployments[0].id).to eq(2)
      end

      it 'raises when the Gitaly version is not recognised' do
        tracker = described_class.new('staging', 'success', version)

        # We're only concerned with Gitaly deployments here, so stub the others
        allow(tracker).to receive(:track_gitlab_deployments).and_return([])
        allow(tracker).to receive(:track_omnibus_deployments).and_return([])
        allow(tracker).to receive(:auto_deploy_intersection).and_return(nil)

        stub_gitaly_server_version('bla')

        expect { tracker.track }.to raise_error(RuntimeError)
      end

      it 'ignores newlines in the Gitaly version' do
        tracker = described_class.new('staging', 'success', version)

        # We're only concerned with Gitaly deployments here, so stub the others
        allow(tracker).to receive(:track_gitlab_deployments).and_return([])
        allow(tracker).to receive(:track_omnibus_deployments).and_return([])
        allow(tracker).to receive(:auto_deploy_intersection).and_return(nil)

        stub_gitaly_server_version("1.2.3-rc1\n")

        expect(ReleaseTools::GitlabClient)
          .to receive(:tag)
          .with(
            ReleaseTools::Project::Gitaly.auto_deploy_path,
            tag: 'v1.2.3-rc1'
          )
          .and_return(
            double(:tag, name: 'v1.2.3-rc1', commit: double(:commit, id: 'abc'))
          )

        expect(ReleaseTools::GitlabClient)
          .to receive(:update_or_create_deployment)
          .with(
            ReleaseTools::Project::Gitaly.auto_deploy_path,
            'staging',
            ref: 'v1.2.3-rc1',
            sha: 'abc',
            status: 'success',
            tag: true
          )
          .and_return(deployment_stub(id: 2, sha: 'abc'))

        deployments = tracker.track

        expect(deployments.length).to eq(1)
        expect(deployments[0].id).to eq(2)
      end
    end

    context 'when using an invalid status' do
      it 'raises ArgumentError' do
        version = '12.7.202001101501-94b8fd8d152.6fea3031ec9'

        expect { described_class.new('staging', 'foo', version).track }
          .to raise_error(ArgumentError)
      end
    end
  end

  describe '#log_new_deployment' do
    it 'logs a new deployment' do
      deploy = double(:deployment, id: 1, iid: 1, ref: 'master', sha: 'abc')
      version = '12.7.202001101501-94b8fd8d152.6fea3031ec9'
      tracker = described_class.new('staging', 'success', version)

      expect(tracker.logger).to receive(:log)

      tracker.send(:log_new_deployment, 'foo/bar', deploy)
    end
  end

  describe '#log_previous_deployment' do
    it 'logs the previous deployment deployment' do
      deploy = double(:deployment, id: 1, iid: 1, ref: 'master', sha: 'abc')
      version = '12.7.202001101501-94b8fd8d152.6fea3031ec9'
      tracker = described_class.new('staging', 'success', version)

      expect(ReleaseTools::GitlabClient)
        .to receive(:deployments)
        .with('foo/bar', 'staging', status: 'success')
        .and_return(Gitlab::PaginatedResponse.new([deploy]))

      expect(tracker.logger).to receive(:log)

      tracker.send(:log_previous_deployment, 'foo/bar')
    end
  end
end
