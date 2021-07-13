# frozen_string_literal: true

module ReleaseTools
  module Support
    module UbiHelper
      DEFAULT_UBI_VERSION = '8'

      def ubi?(version)
        version.ee?
      end

      def ubi_tag(version, ubi_version = nil)
        version.tag(ee: true).gsub(/-ee$/, "-ubi#{ubi_version || DEFAULT_UBI_VERSION}")
      end
    end
  end
end
