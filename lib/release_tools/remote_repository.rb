# frozen_string_literal: true

module ReleaseTools
  class RemoteRepository
    include ::SemanticLogger::Loggable

    OutOfSyncError = Class.new(StandardError)

    class GitCommandError < StandardError
      def initialize(message, output = nil)
        message += "\n\n  #{output.gsub("\n", "\n  ")}" unless output.nil?

        super(message)
      end
    end

    CannotCheckoutBranchError = Class.new(GitCommandError)
    CannotCloneError = Class.new(GitCommandError)
    CannotCommitError = Class.new(GitCommandError)
    CannotCreateTagError = Class.new(GitCommandError)
    CannotPullError = Class.new(GitCommandError)

    CanonicalRemote = Struct.new(:name, :url)
    GitCommandResult = Struct.new(:output, :status)

    def self.get(remotes, repository_name = nil, global_depth: 1, branch: nil)
      repository_name ||= remotes
        .values
        .first
        .split('/')
        .last
        .sub(/\.git\Z/, '')

      new(
        File.join(Dir.tmpdir, repository_name),
        remotes,
        global_depth: global_depth,
        branch: branch
      )
    end

    attr_reader :path, :remotes, :canonical_remote, :global_depth, :branch

    def initialize(path, remotes, global_depth: 1, branch: nil)
      logger.warn("Pushes will be ignored because of TEST env") if SharedStatus.dry_run?

      @path = path
      @global_depth = global_depth
      @branch = branch

      cleanup

      # Add remotes, performing the first clone as necessary
      self.remotes = remotes
    end

    def ensure_branch_exists(branch, base:)
      fetch(branch)

      checkout_branch(branch) || checkout_new_branch(branch, base: base)
    end

    def fetch(ref, remote: canonical_remote.name, depth: global_depth)
      base_cmd = %w[fetch --quiet]
      base_cmd << "--depth=#{depth}" if depth
      base_cmd << remote.to_s

      _, status = run_git([*base_cmd, "#{ref}:#{ref}"])
      _, status = run_git([*base_cmd, ref]) unless status.success?

      status.success?
    end

    def checkout_new_branch(branch, base:)
      fetch(base)

      output, status = run_git %W[checkout --quiet -b #{branch} #{base}]

      status.success? || raise(CannotCheckoutBranchError.new(branch, output))
    end

    # Performs a merge on the repository.
    #
    # @param commits [String] the git reference to merge
    # @param no_ff [true, false] make use of `--no-ff` git parameter
    #
    # @return [GitCommandResult] the result of the operation
    def merge(commits, no_ff: false)
      cmd = %w[merge --no-edit --no-log]
      cmd << '--no-ff' if no_ff
      cmd += Array(commits)

      GitCommandResult.new(*run_git(cmd))
    end

    def pull(ref, remote: canonical_remote.name, depth: global_depth)
      cmd = %w[pull --quiet]
      cmd << "--depth=#{depth}" if depth
      cmd << remote.to_s
      cmd << ref

      output, status = run_git(cmd)

      if conflicts?
        raise CannotPullError.new("Conflicts were found when pulling #{ref} from #{remote}", output)
      end

      status.success?
    end

    def pull_from_all_remotes(ref, depth: global_depth)
      remotes.each_key do |remote_name|
        pull(ref, remote: remote_name, depth: depth)
      end
    end

    def push(remote, ref)
      cmd = %W[push #{remote} #{ref}:#{ref}]

      if SharedStatus.dry_run?
        logger.trace(__method__, remote: remote, ref: ref)

        true
      else
        output, status = run_git(cmd)

        if status.success?
          true
        else
          logger.fatal('Failed to push', remote: remote, ref: ref, output: output)
          false
        end
      end
    end

    def push_to_all_remotes(ref)
      remotes.each_key do |remote_name|
        push(remote_name, ref)
      end
    end

    def cleanup
      logger.trace(__method__, path: path) if Dir.exist?(path)

      FileUtils.rm_rf(path, secure: true)
    end

    def self.run_git(args)
      final_args = ['git', *args].join(' ')

      logger.trace(__method__, command: final_args)

      cmd_output = `#{final_args} 2>&1`

      [cmd_output, $CHILD_STATUS]
    end

    private

    # NOTE: This has been made private, as it's no longer used publicly, but the
    # tests for other methods in this class currently depend on it.
    def log(format: nil)
      format_pattern =
        case format
        when :author
          '%aN'
        when :message
          '%B'
        end

      cmd = %w[log --topo-order]
      cmd << "--format='#{format_pattern}'" if format_pattern

      output, = run_git(cmd)
      output&.squeeze!("\n") if format_pattern == :message

      output
    end

    # NOTE: This has been made private, as it's no longer used publicly, but the
    # tests for other methods in this class currently depend on it.
    def commit(files, no_edit: false, amend: false, message: nil, author: nil)
      run_git ['add', *Array(files)] if files

      cmd = %w[commit]
      cmd << '--no-edit' if no_edit
      cmd << '--amend' if amend
      cmd << %[--author="#{author}"] if author
      cmd += ['--message', %["#{message}"]] if message

      output, status = run_git(cmd)

      status.success? || raise(CannotCommitError.new(output))
    end

    # Given a Hash of remotes {name: url}, add each one to the repository
    def remotes=(new_remotes)
      @remotes = new_remotes.dup
      @canonical_remote = CanonicalRemote.new(*remotes.first)

      new_remotes.each do |remote_name, remote_url|
        # Canonical remote doesn't need to be added twice
        next if remote_name == canonical_remote.name

        add_remote(remote_name, remote_url)
      end
    end

    def add_remote(name, url)
      _, status = run_git %W[remote add #{name} #{url}]

      status.success?
    end

    def checkout_branch(branch)
      output, status = run_git %W[checkout --quiet #{branch}]

      logger.fatal('Failed to checkout', branch: branch, output: output) unless status.success?

      status.success?
    end

    def in_path(&block)
      Dir.chdir(path, &block)
    end

    def conflicts?
      in_path do
        output = `git ls-files -u`
        return !output.empty?
      end
    end

    def run_git(args)
      ensure_repo_exist
      in_path do
        self.class.run_git(args)
      end
    end

    def ensure_repo_exist
      return if File.exist?(path) && File.directory?(File.join(path, '.git'))

      cmd = %w[clone --quiet]
      cmd << "--depth=#{global_depth}" if global_depth
      cmd << "--branch=#{branch}" if branch
      cmd << '--origin' << canonical_remote.name.to_s << canonical_remote.url << path

      output, status = self.class.run_git(cmd)
      unless status.success?
        raise CannotCloneError.new("Failed to clone #{canonical_remote.url} to #{path}", output)
      end
    end
  end
end
