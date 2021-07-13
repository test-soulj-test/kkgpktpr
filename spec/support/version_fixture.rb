# frozen_string_literal: true

require 'fileutils'

require_relative 'repository_fixture'

class VersionFixture
  include RepositoryFixture

  def self.repository_name
    'version'
  end

  def default_fixture_path
    File.expand_path(
      "../fixtures/version",
      __dir__
    )
  end
end
