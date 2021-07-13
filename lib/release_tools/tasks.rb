# frozen_string_literal: true

require 'release_tools/tasks/helper'

require 'release_tools/tasks/auto_deploy/baking_time'
require 'release_tools/tasks/auto_deploy/check_production'
require 'release_tools/tasks/auto_deploy/deploy_trigger'
require 'release_tools/tasks/auto_deploy/prepare'
require 'release_tools/tasks/auto_deploy/tag'

require 'release_tools/tasks/components/update_gitaly'

require 'release_tools/tasks/release/issue'
require 'release_tools/tasks/release/prepare'
