# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Helm::GitlabVersionFinder do
  let(:client) { class_spy(ReleaseTools::GitlabClient) }
  let(:finder) { described_class.new(client) }

  describe '#execute' do
    context 'when the GitLab version is a branch name' do
      it 'raises StandardError' do
        allow(client)
          .to receive(:file_contents)
          .with(
            ReleaseTools::Project::HelmGitlab.canonical_or_security_path,
            'Chart.yaml',
            '4-2-stable'
          )
          .and_raise(gitlab_error(:NotFound))

        allow(client)
          .to receive(:file_contents)
          .with(
            ReleaseTools::Project::HelmGitlab.canonical_or_security_path,
            'Chart.yaml',
            'master'
          )
          .and_return(YAML.dump('appVersion' => 'master'))

        version = ReleaseTools::Version.new('4.2.0')

        expect { finder.execute(version) }.to raise_error(StandardError)
      end
    end

    context 'when the GitLab version is a valid version' do
      it 'returns the GitLab version' do
        allow(client)
          .to receive(:file_contents)
          .with(
            ReleaseTools::Project::HelmGitlab.canonical_or_security_path,
            'Chart.yaml',
            '4-2-stable'
          )
          .and_return(YAML.dump('appVersion' => '1.2.3'))

        version = ReleaseTools::Version.new('4.2.0')

        expect(finder.execute(version))
          .to eq(ReleaseTools::Version.new('1.2.3'))
      end
    end
  end
end
