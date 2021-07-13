# frozen_string_literal: true

require 'spec_helper'

require 'rubocop'
require 'rubocop/rspec/support'
require 'rubocop/release_tools'

RSpec.describe RuboCop::Cop::ReleaseTools::DefaultBranchLiteral do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  it 'registers an offense when using a `master` literal' do
    expect_offense(<<~RUBY)
      push_branch('master')
                  ^^^^^^^^ Use a project's `default_branch` method instead of a String literal.
    RUBY
  end

  it 'does not register an offense when using any other String literal' do
    expect_no_offenses(<<~RUBY)
      push_branch('foo')
    RUBY
  end
end
