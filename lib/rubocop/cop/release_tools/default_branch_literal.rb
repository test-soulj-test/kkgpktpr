# frozen_string_literal: true

module RuboCop
  module Cop
    module ReleaseTools
      # Avoid default branch literals
      #
      # @example
      #   # bad
      #   push_branch('master')
      #
      #   # good
      #   push_branch(ReleaseTools::Project::GitlabEe.default_branch)
      #
      class DefaultBranchLiteral < Cop
        MSG = "Use a project's `default_branch` method instead of a String literal."

        def_node_matcher :default_branch_literal?, <<~PATTERN
          (str "master")
        PATTERN

        def on_str(node)
          return unless default_branch_literal?(node)

          add_offense(node)
        end
      end
    end
  end
end
