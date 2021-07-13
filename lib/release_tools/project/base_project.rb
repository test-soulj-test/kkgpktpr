# frozen_string_literal: true

module ReleaseTools
  module Project
    class BaseProject
      REMOTE_PATTERN = %r{
        \A.*:
        (?<group>.*)
        /
        (?<project>[^/]+)
        \.git\z
      }x.freeze

      def self.default_branch
        'master'
      end

      def self.remotes
        if SharedStatus.security_release?
          self::REMOTES.slice(:dev, :security)
        else
          self::REMOTES
        end
      end

      def self.path
        extract_path_from_remote(:canonical).captures.join('/')
      end

      def self.dev_path
        extract_path_from_remote(:dev).captures.join('/')
      end

      def self.ops_path
        extract_path_from_remote(:ops).captures.join('/')
      end

      def self.security_path
        extract_path_from_remote(:security).captures.join('/')
      end

      def self.group
        extract_path_from_remote(:canonical)[:group]
      end

      def self.dev_group
        extract_path_from_remote(:dev)[:group]
      end

      def self.ops_group
        extract_path_from_remote(:ops)[:group]
      end

      def self.security_group
        extract_path_from_remote(:security)[:group]
      end

      def self.project_name
        extract_path_from_remote(:canonical)[:project]
      end

      def self.metadata_project_name
        project_name
      end

      def self.canonical_or_security_path
        # This method exists so that it's more clear that one wants the path
        # based on the security release status, as using `#to_s` could make one
        # think they can just remove the use of `#to_s` and produce the same
        # result.
        to_s
      end

      def self.auto_deploy_path
        security_path
      end

      def self.to_s
        if SharedStatus.security_release?
          security_path
        else
          path
        end
      end

      def self.inspect
        if const_defined?(:REMOTES)
          to_s
        else
          super
        end
      end

      def self.extract_path_from_remote(remote_key)
        remote = self::REMOTES.fetch(remote_key) do |name|
          raise "Invalid remote for #{path}: #{name}"
        end

        if remote =~ REMOTE_PATTERN
          $LAST_MATCH_INFO
        else
          raise "Unable to extract path from #{remote}"
        end
      end

      private_class_method :extract_path_from_remote

      def self.security_client
        GitlabClient
      end
    end
  end
end
