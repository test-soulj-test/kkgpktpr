# frozen_string_literal: true

require 'fileutils'
require 'rugged'

require_relative 'repository_fixture'

class ReleaseFixture
  include RepositoryFixture

  def self.repository_name
    'release'
  end

  DEFAULT_OPTIONS = { gitaly_version: '5.6.0' }.freeze

  def build_fixture(options = {})
    options = DEFAULT_OPTIONS.merge(options)

    commit_blob(
      path:    'README.md',
      content: 'Sample README.md',
      message: 'Add a simple README.md'
    )

    create_prefixed_master

    gemfile = File.join(VersionFixture.new.default_fixture_path, 'Gemfile.lock')
    commit_blob(
      path:    'Gemfile.lock',
      content: File.read(gemfile),
      message: 'Add Gemfile.lock'
    )

    commit_blobs(
      {
        'GITLAB_SHELL_VERSION'                 => "2.2.2\n",
        'GITLAB_WORKHORSE_VERSION'             => "3.3.3\n",
        'GITALY_SERVER_VERSION'                => "1.1.1\n",
        'GITLAB_ELASTICSEARCH_INDEXER_VERSION' => "6.6.6\n",
        'VERSION'                              => "1.1.1\n"
      }
    )

    repository.checkout("#{branch_prefix}master")

    # Create a basic branch
    repository.branches.create("#{branch_prefix}branch-1", 'HEAD')

    # Create old stable branches
    repository.branches.create("#{branch_prefix}1-9-stable",    'HEAD')
    repository.branches.create("#{branch_prefix}1-9-stable-ee", 'HEAD')

    repository.tags.create('v1.9.0', 'HEAD', message: 'GitLab Version 1.9.0')

    # At some point we release Pages!
    commit_blobs({ 'GITLAB_PAGES_VERSION' => "4.4.4\n" })

    # Create new stable branches
    repository.branches.create("#{branch_prefix}9-1-stable",    'HEAD')
    repository.branches.create("#{branch_prefix}9-1-stable-ee", 'HEAD')

    repository.tags.create('v9.1.0', 'HEAD', message: 'GitLab Version 9.1.0')

    # Bump the versions in master
    commit_blobs(
      {
        'GITALY_SERVER_VERSION'                => "#{options[:gitaly_version]}\n",
        'GITLAB_PAGES_VERSION'                 => "4.5.0\n",
        'GITLAB_SHELL_VERSION'                 => "2.3.0\n",
        'GITLAB_WORKHORSE_VERSION'             => "3.4.0\n",
        'GITLAB_ELASTICSEARCH_INDEXER_VERSION' => "9.9.9\n",
        'VERSION'                              => "1.2.0\n"
      }
    )

    repository.checkout("#{branch_prefix}master")
  end
end
