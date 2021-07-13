# frozen_string_literal: true

require 'slack-ruby-block-kit'

require 'release_tools/slack/webhook'
require 'release_tools/slack/auto_deploy_notification'
require 'release_tools/slack/chatops_notification'
require 'release_tools/slack/merge_train_notification'
require 'release_tools/slack/message'
require 'release_tools/slack/tag_notification'

module ReleaseTools
  module Slack
    F_UPCOMING_RELEASE = 'C0139MAV672'
    GITALY_ALERTS = 'C4MU5R2MD'
    RELEASE_MANAGERS = 'S0127FU8PDE'
  end
end
