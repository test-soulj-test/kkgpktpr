# frozen_string_literal: true

module ReleaseTools
  class OmnibusGitlabVersion < Version
    VERSION_REGEX = %r{
      \A(?<major>\d+)
      \.(?<minor>\d+)
      (\.(?<patch>\d+))?
      (\+)?
      (?<rc>rc(?<rc_number>\d*))?
      (\.)?
      (?<edition>ce|ee)?
      (\.\d+)?\z
    }x.freeze

    OMNIBUS_SINGLE_BRANCH_VERSION = ENV.fetch('OMNIBUS_SINGLE_BRANCH_VERSION', '12.3.0')

    def ee?
      edition == 'ee'
    end

    def to_ce
      return self unless ee?

      self.class.new(to_s.sub(/(\+|\.)ee/, '\1ce'))
    end

    def to_ee
      return self if ee?

      self.class.new(to_s.sub(/(\+|\.)ce/, '\1ee'))
    end

    def edition
      @edition ||= extract_from_version(:edition, fallback: 'ce')
    end

    def tag
      str = +"#{to_patch}+"
      str << "rc#{rc}." if rc?
      str << (ee? ? 'ee' : 'ce')
      str << '.0'
    end

    # For omnibus-gitlab, we have a single stable branch starting with
    # version specified in the env variable OMNIBUS_SINGLE_BRANCH_VERSION.
    # So, we are stripping off `-ee` suffix.
    def stable_branch(ee: false)
      super.tap do |branch|
        branch.chomp!('-ee') if self >= ReleaseTools::Version.new(OMNIBUS_SINGLE_BRANCH_VERSION)
      end
    end
  end
end
