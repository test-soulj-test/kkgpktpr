# frozen_string_literal: true

module ReleaseTools
  class MergeRequest < Issuable
    def milestone
      self[:milestone] || nil
    end

    def source_branch
      self[:source_branch] || raise(ArgumentError, 'Please set a `source_branch`!')
    end

    def target_branch
      self[:target_branch] || project.default_branch
    end

    def create
      GitlabClient.create_merge_request(self, project)
    end

    def accept
      GitlabClient.accept_merge_request(self, project)
    end

    def approve
      GitlabClient.approve_merge_request(self, project)
    end

    def to_reference
      "#{project.path}!#{iid}"
    end

    def conflicts
      self[:conflicts] || nil
    end

    def conflicts?
      conflicts&.any?
    end

    def remote_issuable
      @remote_issuable ||= GitlabClient.find_merge_request(self, project)
    end
  end
end
