# frozen_string_literal: true

module ReleaseTools
  module ReleaseManagers
    # Represents all defined Release Managers
    class Definitions
      extend Forwardable
      include Enumerable

      INSTANCES = %i(production dev ops).freeze

      attr_accessor :config_file
      attr_reader :all

      def_delegator :@all, :each

      class << self
        extend Forwardable

        def_delegator :new, :allowed?
        def_delegator :new, :sync!
      end

      def initialize(config_file = nil)
        @config_file = config_file ||
          File.expand_path('../../../config/release_managers.yml', __dir__)

        reload!
      end

      def allowed?(username)
        any? { |user| user.production.casecmp?(username) }
      end

      def reload!
        begin
          content = YAML.load_file(config_file)
          raise ArgumentError, "#{config_file} contains no data" if content.blank?
        rescue Errno::ENOENT
          raise ArgumentError, "#{config_file} does not exist!"
        end

        @all = content.map { |name, hash| User.new(name, hash) }
      end

      def sync!
        release_managers = active_release_managers

        slack_wrapper_client.sync_membership(release_managers.collect(&:slack).compact)
        dev_client.sync_membership(release_managers.collect(&:dev))
        production_client.sync_membership(release_managers.collect(&:production))
        ops_client.sync_membership(release_managers.collect(&:ops))

        ReleaseManagers::SyncResult.new([slack_wrapper_client, dev_client, production_client, ops_client])
      end

      def find_user(username, instance: :production)
        raise ArgumentError, "Unknown instance #{instance}" unless INSTANCES.include?(instance)

        find do |user|
          user.send(instance) == username
        end
      end

      # Returns an Array of users matching the provided names
      #
      # @param [Array<String>] the names to find a user for
      # @return [Array<ReleaseTools::ReleaseManagers::Definitions::User>]
      def find_by_name(names)
        find_all do |user|
          names.include?(user.name)
        end
      end

      private

      def dev_client
        @dev_client ||= ReleaseManagers::Client.new(:dev)
      end

      def production_client
        @production_client ||= ReleaseManagers::Client.new(:production)
      end

      def ops_client
        @ops_client ||= ReleaseManagers::Client.new(:ops)
      end

      def slack_wrapper_client
        @slack_wrapper_client ||= ReleaseManagers::SlackWrapperClient.new
      end

      def active_release_managers
        active = Schedule.new.active_release_managers.collect(&:username)

        all.select { |user| active.include?(user.production) }
      end

      # Represents a single entry from the configuration file
      class User
        attr_reader :name
        attr_reader :dev, :production, :ops, :slack

        def initialize(name, hash)
          if hash['gitlab.com'].nil?
            raise ArgumentError, "No `gitlab.com` value for #{name}"
          end

          @name = name

          @production = hash['gitlab.com']
          @dev = hash['gitlab.org'] || production
          @ops = hash['ops.gitlab.net'] || production

          @slack = hash['slack']
        end
      end
    end
  end
end
