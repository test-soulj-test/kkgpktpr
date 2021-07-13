# frozen_string_literal: true

namespace :components do
  desc 'Prepare a merge request for updating GITALY_SERVER_VERSION on gitlab master branch'
  task :update_gitaly do
    ReleaseTools::Tasks::Components::UpdateGitaly.new.execute
  end
end
