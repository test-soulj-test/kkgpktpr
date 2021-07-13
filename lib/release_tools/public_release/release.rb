# frozen_string_literal: true

module ReleaseTools
  module PublicRelease
    # An interface for API release classes.
    #
    # This interface/module provides a variety of default methods, and methods
    # that an including class must implement. By implementing these methods,
    # release classes can reuse behaviour (such as creating a tag) that is the
    # same for all release classes, while still being able to override behaviour
    # where necessary.
    #
    # This module must not dictate the implementation of releases, beyond
    # requiring some methods that have to be implemented to use the methods
    # provided by this module.
    #
    # For example, the `execute` method in this module is deliberately left
    # empty (besides raising an error). If this method were to instead call
    # other methods (e.g. a method for compiling a changelog), releases classes
    # would have to start overwriting methods the moment they want to change
    # this behaviour. Such tight coupling can make for code that is hard to
    # debug, understand, test, and extend.
    #
    # In other words, all this module should do is:
    #
    # 1. Provide a public interface (but _not_ an implementation) for release
    #    classes.
    # 2. Provide some default methods that most release classes will need. As a
    #    rule of thumb, don't add a method here unless it's used by three or
    #    more release classes.
    module Release
      PRODUCTION_ENVIRONMENT = 'gprd'

      def self.included(into)
        into.include(::SemanticLogger::Loggable)
      end

      def release_metadata
        raise NotImplementedError
      end

      def version
        raise NotImplementedError
      end

      def project
        raise NotImplementedError
      end

      def client
        raise NotImplementedError
      end

      def execute
        raise NotImplementedError
      end

      def project_path
        project.canonical_or_security_path
      end

      def tag_name
        version.tag
      end

      def source_for_target_branch
        last_production_commit
      end

      def target_branch
        version.stable_branch
      end

      def create_target_branch
        source = source_for_target_branch

        logger.info(
          'Creating target branch',
          project: project_path,
          source: source,
          branch: target_branch
        )

        client.find_or_create_branch(target_branch, source, project_path)
      end

      def notify_slack(project, version)
        path = project.canonical_or_security_path

        logger.info('Notifying Slack', project: path, version: version)
        Slack::TagNotification.release(project, version)
      end

      def last_production_commit
        env = PRODUCTION_ENVIRONMENT

        # Branches are to always be created on the public projects, using the
        # deployments tracked in those projects. To ensure this we use the
        # public project path. This way even during a security release we fetch
        # this data from the public project.
        sha = client.deployments(project.path, env).first&.sha

        unless sha
          raise "The project #{project_path} has no deployments for #{env}. " \
            'If this project does not use GitLab deployments, re-define the ' \
            'source_for_target_branch instance method to return the source ' \
            'branch name'
        end

        sha
      end

      # Update one or more VERSION files.
      #
      # The `versions` argument is a `Hash` that maps version file names (e.g.
      # `VERSION` or `GITALY_SERVER_VERSION`) to their new version identifiers.
      # For example:
      #
      #     { 'VERSION' => '1.2.3', 'GITALY_SERVER_VERSION' => '2.3.4' }
      #
      # By default this method will trigger pipelines for the commit it creates,
      # as this is the safest default. To disable this, set `skip_ci` to `true`.
      # rubocop: disable Metrics/ParameterLists
      def commit_version_files(
        branch,
        versions,
        message: 'Update VERSION files',
        project: project_path,
        skip_ci: false,
        skip_merge_train: false
      )
        actions = versions.each_with_object([]) do |(file, version), memo|
          action =
            begin
              # We strip newlines from both the old file contents and the new
              # contents. This ensures that if the old file contains a trailing
              # newline, and the new content does as well, we don't create empty
              # commits. This _does_ happen if we compare the existing stripped
              # content with the new content as-is, provided said new content
              # contains a trailing newline.
              if client.file_contents(project, file, branch).strip != version.strip
                'update'
              end
            rescue Gitlab::Error::NotFound
              'create'
            end

          next unless action

          logger.info(
            "Setting version file #{file} to #{version.tr("\n", ' ')}",
            project: project,
            action: action,
            file: file,
            version: version,
            branch: branch
          )

          memo << { action: action, file_path: file, content: version }
        end

        return if actions.empty?

        tags = []

        tags << '[ci skip]' if skip_ci
        tags << '[merge-train skip]' if skip_merge_train

        message += "\n\n#{tags.join("\n")}" if tags.any?

        client.create_commit(project, branch, message, actions)
      end
      # rubocop: enable Metrics/ParameterLists
    end
  end
end
