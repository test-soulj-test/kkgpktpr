# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::RemoteRepository, :slow do
  include RuggedMatchers

  let(:fixture) { ReleaseFixture.new }
  let(:repo_path) { File.join(Dir.tmpdir, fixture.class.repository_name) }
  let(:rugged_repo) { Rugged::Repository.new(repo_path) }
  let(:repo_url) { "file://#{fixture.fixture_path}" }
  let(:repo_remotes) do
    { canonical: repo_url, foo: 'https://example.com/foo/bar/baz.git' }
  end

  def write_file(file, content)
    Dir.chdir(repo_path) do
      File.write(file, content)
    end
  end

  before do
    fixture.rebuild_fixture!
  end

  describe '.get' do
    let(:remotes) do
      {
        dev:    'https://example.com/foo/bar/dev.git',
        canonical: 'https://gitlab.com/gitlab-org/foo/gitlab.git'
      }
    end

    it 'generates a name from the first remote' do
      expect(described_class).to receive(:new).with("#{Dir.tmpdir}/dev", anything, anything)

      described_class.get(remotes)
    end

    it 'accepts a repository name' do
      expect(described_class).to receive(:new).with("#{Dir.tmpdir}/foo", anything, anything)

      described_class.get(remotes, 'foo')
    end

    it 'passes remotes to the initializer' do
      expect(described_class).to receive(:new).with(anything, remotes, anything)

      described_class.get(remotes)
    end

    it 'accepts a :global_depth option' do
      expect(described_class).to receive(:new)
        .with(anything, anything, a_hash_including(global_depth: 100))

      described_class.get(remotes, global_depth: 100)
    end
  end

  describe 'initialize' do
    it 'performs cleanup' do
      expect_any_instance_of(described_class).to receive(:cleanup)

      described_class.new(repo_path, {})
    end

    it 'performs a shallow clone of the repository' do
      described_class.new(repo_path, repo_remotes)

      # Note: Rugged has no clean way to do this, so we'll shell out
      expect(`git -C #{repo_path} log --oneline | wc -l`.to_i)
        .to eq(1)
    end

    it 'adds remotes to the repository' do
      expect_any_instance_of(described_class).to receive(:remotes=)
        .with(:remotes)

      described_class.new('foo', :remotes)
    end

    it 'assigns path' do
      repository = described_class.new('foo', {})

      expect(repository.path).to eq 'foo'
    end
  end

  describe '#remotes=' do
    it 'assigns the canonical remote' do
      remotes = { canonical: repo_url }

      repository = described_class.new(repo_path, remotes)

      expect(repository.canonical_remote.name).to eq(:canonical)
      expect(repository.canonical_remote.url).to eq(repo_url)
    end

    it 'assigns remotes' do
      remotes = { canonical: repo_url }

      repository = described_class.new(repo_path, remotes)

      expect(repository.remotes).to eq(remotes)
    end

    it 'adds remotes to the repository', :aggregate_failures do
      remotes = {
        canonical: repo_url,
        foo: '/foo/bar/baz.git'
      }

      repository = described_class.new(repo_path, remotes)
      rugged = Rugged::Repository.new(repository.path)

      expect(rugged.remotes.count).to eq(2)
      expect(rugged.remotes['canonical'].url).to eq(repo_url)
      expect(rugged.remotes['foo'].url).to eq('/foo/bar/baz.git')
    end
  end

  describe '#ensure_branch_exists' do
    subject { described_class.get(repo_remotes) }

    context 'with an existing branch' do
      it 'fetches and checks out the branch with the configured global depth', :aggregate_failures do
        expect(subject.logger).not_to receive(:fatal)

        subject.ensure_branch_exists('branch-1', base: 'master')

        expect(rugged_repo).to have_head('branch-1')
        expect(rugged_repo).to have_blob('README.md').with('Sample README.md')
        expect(`git -C #{repo_path} log --oneline | wc -l`.to_i).to eq(1)
      end
    end

    context 'with a non-existing branch' do
      it 'creates and checks out the branch with the configured global depth', :aggregate_failures do
        expect(subject.logger).to receive(:fatal).and_call_original

        subject.ensure_branch_exists('branch-2', base: 'master')

        expect(rugged_repo).to have_head('branch-2')
        expect(rugged_repo).to have_blob('README.md').with('Sample README.md')
        expect(`git -C #{repo_path} log --oneline | wc -l`.to_i).to eq(1)
      end
    end
  end

  describe '#fetch' do
    subject { described_class.get(repo_remotes) }

    it 'fetches the branch with the default configured global depth' do
      subject.fetch('branch-1')

      expect(`git -C #{repo_path} log --oneline refs/heads/branch-1 | wc -l`.to_i).to eq(1)
    end

    context 'with a depth option given' do
      it 'fetches the branch up to the given depth' do
        subject.fetch('branch-1', depth: 2)

        expect(`git -C #{repo_path} log --oneline refs/heads/branch-1 | wc -l`.to_i).to eq(2)
      end
    end
  end

  describe '#checkout_new_branch' do
    subject { described_class.get(repo_remotes) }

    it 'creates and checks out a new branch' do
      subject.checkout_new_branch('new-branch', base: 'master')

      expect(rugged_repo).to have_version('pages').at('4.5.0')
    end

    context 'with a given base branch' do
      it 'creates and checks out a new branch based on the given base branch' do
        subject.checkout_new_branch('new-branch', base: '9-1-stable')

        expect(rugged_repo).to have_version('pages').at('4.4.4')
      end
    end
  end

  describe '#merge' do
    subject { described_class.get(repo_remotes, global_depth: 10) }

    before do
      subject.fetch('master')
      subject.ensure_branch_exists('branch-1', base: 'master')
      subject.ensure_branch_exists('branch-2', base: 'master')
      write_file('README.md', 'Nice')
      subject.__send__(:commit, 'README.md', message: 'Update README.md')
      subject.ensure_branch_exists('branch-1', base: 'master')
    end

    it 'commits the given files with the given message in the current branch' do
      expect(subject.merge('branch-2', no_ff: true).status).to be_success
      log = subject.__send__(:log, format: :message)

      expect(log).to start_with("Merge branch 'branch-2' into branch-1\n")
      expect(File.read(File.join(repo_path, 'README.md'))).to eq 'Nice'
    end

    it 'performs an octopus merge with an array of commits' do
      write_file('foo', 'bar')
      subject.__send__(:commit, 'foo', message: 'Add foo')

      subject.ensure_branch_exists('branch-3', base: 'master')

      expect(subject.merge(%w[branch-1 branch-2], no_ff: true).status).to be_success
      log = subject.__send__(:log, format: :message)

      expect(File.read(File.join(repo_path, 'README.md'))).to eq 'Nice'
      expect(File.read(File.join(repo_path, 'foo'))).to eq 'bar'
      expect(log).to start_with("Merge branches 'branch-1' and 'branch-2' into branch-3\n")
    end

    context 'in case of conflicts' do
      before do
        subject.ensure_branch_exists('branch-1', base: 'master')
        write_file('README.md', 'branch-1')
        subject.__send__(:commit, 'README.md', message: 'Update README.md')

        subject.ensure_branch_exists('branch-2', base: 'master')
        write_file('foo', 'foo')
        subject.__send__(:commit, 'foo', message: 'Add foo')

        subject.ensure_branch_exists('branch-1', base: 'master')
      end

      it 'fails when no recursive strategy is specified' do
        expect(subject.merge('branch-2', no_ff: true).status).not_to be_success
      end
    end
  end

  describe '#pull' do
    subject { described_class.get(repo_remotes) }

    it 'pulls the branch with the configured depth' do
      expect { subject.pull('master') }
        .not_to(change { subject.__send__(:log, format: :message).lines.size })
    end

    context 'with a depth option given' do
      it 'pulls the branch with to the given depth' do
        expect { subject.pull('master', depth: 2) }
          .to change { subject.__send__(:log, format: :message).lines.size }.from(1).to(2)
      end
    end
  end

  describe '#pull_from_all_remotes' do
    subject { described_class.get(Hash[*repo_remotes.first]) }

    context 'when there are conflicts' do
      it 'raises a CannotPullError error' do
        allow(subject).to receive(:conflicts?).and_return(true)

        expect { subject.pull_from_all_remotes('1-9-stable') }
          .to raise_error(described_class::CannotPullError)
      end
    end

    it 'does not raise error' do
      expect { subject.pull_from_all_remotes('master') }
        .not_to raise_error
    end

    context 'with a depth option given' do
      it 'pulls the branch down to the given depth' do
        expect { subject.pull_from_all_remotes('master', depth: 2) }
          .to change { subject.__send__(:log, format: :message).lines.size }.from(1).to(2)
      end
    end
  end

  describe '#cleanup' do
    it 'removes the repository path' do
      repository = described_class.new(repo_path, {})

      expect(FileUtils).to receive(:rm_rf).with(repo_path, secure: true)

      repository.cleanup
    end
  end

  describe described_class::GitCommandError do
    it 'adds indented output to the error message' do
      error = described_class.new("Foo", "bar\nbaz")

      expect(error.message).to eq "Foo\n\n  bar\n  baz"
    end
  end
end
