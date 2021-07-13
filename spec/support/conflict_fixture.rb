# frozen_string_literal: true

require 'fileutils'
require 'rugged'

require_relative 'repository_fixture'

class ConflictFixture
  include RepositoryFixture

  def self.repository_name
    'conflict'
  end

  def build_fixture(options = {})
    commit_blob(
      path:    'CONTRIBUTING.md',
      content: 'Sample CONTRIBUTING.md',
      message: 'Add a sample CONTRIBUTING.md',
      author: options[:author]
    )

    commit_blob(
      path:    'README.md',
      content: 'Sample README.md',
      message: 'Add a sample README.md',
      author: options[:author]
    )
  end

  def update_file(file, content, options = {})
    commit_blob(
      path:    file,
      content: content,
      message: "Update #{file}",
      author: options[:author]
    )
  end
end
