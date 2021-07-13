# frozen_string_literal: true

module RuggedMatchers
  extend RSpec::Matchers::DSL

  # Read a blob at `path` from a repository's current HEAD
  #
  # repository - Rugged::Repository object
  # path       - Path String
  #
  # Returns a stripped String
  def read_head_blob(repository, path)
    head = repository.head

    repository
      .blob_at(head.target_id, path)
      .content
      .strip
  end

  # Verify that the current HEAD is the given one
  matcher :have_head do |head|
    def denormalize_head(ref)
      ref.delete_prefix('refs/heads/')
    end

    match do |repository|
      @repository = repository
      @expected_head = denormalize_head(head)
      @actual_head = denormalize_head(@repository.head.name)

      @expected_head == @actual_head
    end

    failure_message do
      %[expected HEAD of #{File.join(@repository.workdir)} to be "#{@expected_head}", but was "#{@actual_head}"]
    end

    failure_message_when_negated do
      %[expected HEAD of #{File.join(@repository.workdir)} not to be "#{@expected_head}", but was "#{@actual_head}"]
    end
  end

  # Verify that the current HEAD or given commit has the given title
  matcher :have_commit_title do |title|
    chain :for do |ref|
      @ref = ref
    end

    match do |repository|
      @repository = repository
      @expected_title = title
      commit = @ref ? @repository.rev_parse(@ref) : @repository.head.target
      @actual_title = commit.message.lines.first.chomp

      @expected_title == @actual_title
    end

    failure_message do
      %[expected last commit title of #{@ref || 'HEAD'} from #{File.join(@repository.workdir)} to be "#{@expected_title}", but was "#{@actual_title}"]
    end

    failure_message_when_negated do
      %[expected last commit title of #{@ref || 'HEAD'} from #{File.join(@repository.workdir)} not to be "#{@expected_title}"]
    end
  end

  # Verify that `repository` contains `file_path` for HEAD or given `ref`, `with`
  # the given optional content.
  matcher :have_blob do |file_path|
    chain :for do |ref|
      @ref = ref
    end

    chain :with do |content|
      @content = content
    end

    match do |repository|
      @repository = repository
      @commit = @ref ? @repository.rev_parse(@ref) : @repository.head.target
      blob = @repository.blob_at(@commit.oid, file_path)

      return false if blob.nil?
      return true if @content.nil?

      @actual_content = blob.content

      @content == @actual_content
    end

    failure_message do
      msg = "expected #{file_path} to exist in tree for #{@ref || @commit.oid}"
      if @content
        msg << %[ with "#{@content}" as content]
        msg << %[ but contained "#{@actual_content}" instead] if @actual_content
      end

      msg
    end

    failure_message_when_negated do
      "expected #{file_path} not to exist in tree for #{@ref || @commit.oid}"
    end
  end

  # Verify that `repository` has a version file at a specific version
  #
  # If no filename is given, `VERSION` will be read. Otherwise a
  # `GITLAB_[FILENAME]_VERSION` file will be read.
  #
  # Examples:
  #
  #   expect(repository).to have_version.at('1.2.3')
  #   expect(repository).to have_version('pages').at('2.3.4')
  #   expect(repository).to have_version('workhorse').at('3.4.5')
  #   expect(repository).not_to have_version('pages')
  matcher :have_version do |file_path|
    def normalize_path(file_path)
      if file_path.nil?
        'VERSION'
      elsif file_path.eql?('gitaly')
        'GITALY_SERVER_VERSION'
      else
        "GITLAB_#{file_path.upcase}_VERSION"
      end
    end

    chain :at do |version|
      @version = version
    end

    match do |repository|
      @repository = repository
      @actual = normalize_path(file_path)

      begin
        read_head_blob(repository, @actual) == @version
      rescue NoMethodError
        false
      end
    end

    match_when_negated do |repository|
      @repository = repository
      @actual = normalize_path(file_path)

      begin
        read_head_blob(repository, @actual)
      rescue NoMethodError
        true
      else
        false
      end
    end

    failure_message do
      if @version
        actual_version = read_head_blob(@repository, @actual)

        "expected #{File.join(@repository.workdir, @actual)} to be #{@version} but was #{actual_version}"
      else
        "expected #{File.join(@repository.workdir, @actual)} to exist but does not"
      end
    end

    failure_message_when_negated do
      if @version
        actual_version = read_head_blob(@repository, @actual)

        "expected #{File.join(@repository.workdir, @actual)} not to be #{actual_version}"
      else
        "expected #{@repository.workdir} not to contain #{@actual}"
      end
    end
  end
end
