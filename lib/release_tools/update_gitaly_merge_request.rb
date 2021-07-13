# frozen_string_literal: true

module ReleaseTools
  class UpdateGitalyMergeRequest < MergeRequest
    STALE_AFTER = 1.day.ago
    NOTIFIED_LABEL = 'auto updated'

    def title
      "Update Gitaly version"
    end

    def labels
      ['team::Delivery', 'dependency update', 'group::gitaly', 'feature::maintenance']
    end

    def target_branch
      Project::Gitaly.default_branch
    end

    def fresh?
      return false unless exists?

      Time.parse(remote_issuable.created_at) >= STALE_AFTER
    end

    def notifiable?
      return false unless exists?
      return false if fresh?

      # When we first consider the merge request stale, a specific label is
      # applied. Checking for the label prevents us from sending multiple
      # notifications for the same merge request.
      remote_issuable.labels.exclude?(NOTIFIED_LABEL)
    end

    def mark_as_stale
      comment = <<~BODY
        This merge request has been open for too long and will need manual
        intervention.

        /label ~"#{NOTIFIED_LABEL}"
      BODY

      Retriable.with_context(:api) do
        GitlabClient.create_merge_request_comment(project_id, iid, comment)
      end
    end

    protected

    def template_path
      File.expand_path('../../templates/update_gitaly_merge_request.md.erb', __dir__)
    end
  end
end
