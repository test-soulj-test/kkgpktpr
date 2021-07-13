# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::Qa::Ref do
  let(:stable_branch_ref) { '10-0-stable' }
  let(:release_tag_ref) { 'v10.0.0' }
  let(:rc_tag_ref) { 'v10.0.0-rc1' }

  describe '#ref' do
    it 'returns the EE commit when using an auto deploy ref' do
      ref = described_class.new('v12.0.2019123-123456123456.456789456789')

      expect(ref.ref).to eq('123456123456')
    end

    it 'returns the ref as-is when using a regular tag' do
      ref = described_class.new('v12.0.0')

      expect(ref.ref).to eq('v12.0.0')
    end

    it 'returns the input ref for a patch version' do
      ref = described_class.new('v12.8.0-ee.0')

      expect(ref.ref).to eq('v12.8.0-ee.0')
    end
  end

  describe '#for_project' do
    let(:project) { ReleaseTools::Project::GitlabEe }

    it 'returns the stable branch ref' do
      ref = described_class.new(stable_branch_ref)

      expect(ref.for_project(project)).to eq('10-0-stable-ee')
    end

    it 'returns the release tag ref' do
      ref = described_class.new(release_tag_ref)

      expect(ref.for_project(project)).to eq('v10.0.0-ee')
    end

    it 'returns the rc tag ref' do
      ref = described_class.new(rc_tag_ref)

      expect(ref.for_project(project)).to eq('v10.0.0-rc1-ee')
    end

    it 'returns the correct alternate branch ref' do
      ref = described_class.new('branch')

      expect(ref.for_project(project)).to eq('branch')
    end

    it 'returns the correct master branch ref' do
      ref = described_class.new('master')

      expect(ref.for_project(project)).to eq('master')
    end

    it 'returns the gitlab-rails SHA for an auto-deploy ref' do
      ref = described_class.new('13.5.202010191220-26eafa3e131.4259f2c7324')

      expect(ref.for_project(project)).to eq('26eafa3e131')
    end

    it 'returns the correct sha' do
      ref = described_class.new('cdb7aec191347cf004447b2d6124e5e394c033f4')

      expect(ref.for_project(project)).to eq('cdb7aec191347cf004447b2d6124e5e394c033f4')
    end

    it 'returns component version at the given gitlab-rails ref' do
      project = ReleaseTools::Project::Gitaly
      ref = described_class.new('13.5.202010200520-105dc62a780.8b82c9a9104')

      expect(ReleaseTools::GitlabClient).to receive(:file_contents)
        .with(ReleaseTools::Project::GitlabEe.security_path, project.version_file, '105dc62a780')
        .and_return("abcdef\n")

      expect(ref.for_project(project)).to eq('abcdef')
    end

    it 'returns component version at the given gitlab-rails ref for Workhorse' do
      project = ReleaseTools::Project::GitlabWorkhorse
      ref = described_class.new('13.5.202010200520-105dc62a780.8b82c9a9104')

      expect(ReleaseTools::GitlabClient).to receive(:file_contents)
        .with(ReleaseTools::Project::GitlabEe.security_path, project.version_file, '105dc62a780')
        .and_return("VERSION\n")

      expect(ReleaseTools::GitlabClient).to receive(:file_contents)
        .with(ReleaseTools::Project::GitlabEe.security_path, 'VERSION', '105dc62a780')
        .and_return("abcdef\n")

      expect(ref.for_project(project)).to eq('abcdef')
    end

    # When running QA for a tagged EE release, we need to fetch a component
    # uisng the suffixed tag, but prefix a SemVer component version
    it 'returns a prefixed component tag for a SemVer ref' do
      project = ReleaseTools::Project::GitlabWorkhorse
      ref = described_class.new('v13.3.7')

      expect(ReleaseTools::GitlabClient).to receive(:file_contents)
        .with(ReleaseTools::Project::GitlabEe.security_path, project.version_file, 'v13.3.7-ee')
        .and_return("12.3.4\n")

      expect(ref.for_project(project)).to eq('v12.3.4')
    end

    # When running QA for a tagged EE release, we need to fetch a component
    # using the suffixed tag, but then not modify an already-prefixed component
    # tag version
    it 'returns the given ref for a prefixed SemVer ref' do
      project = ReleaseTools::Project::Gitaly
      ref = described_class.new('v13.3.7')

      expect(ReleaseTools::GitlabClient).to receive(:file_contents)
        .with(ReleaseTools::Project::GitlabEe.security_path, project.version_file, 'v13.3.7-ee')
        .and_return("v13.4.5\n")

      expect(ref.for_project(project)).to eq('v13.4.5')
    end

    it 'returns given ref for EE' do
      project = ReleaseTools::Project::GitlabEe
      ref = described_class.new('13.5.202010200520-105dc62a780.8b82c9a9104')

      expect(ReleaseTools::GitlabClient).not_to receive(:file_contents)

      expect(ref.for_project(project)).to eq('105dc62a780')
    end
  end
end
