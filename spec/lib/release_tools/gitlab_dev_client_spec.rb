# frozen_string_literal: true

require 'spec_helper'

describe ReleaseTools::GitlabDevClient do
  describe '.project_path' do
    it 'returns the correct project dev_path' do
      project = double(dev_path: 'foo/bar')

      expect(described_class.project_path(project)).to eq 'foo/bar'
    end

    it 'returns a String unmodified' do
      project = 'gitlabhq/gitlab'

      expect(described_class.project_path(project)).to eq(project)
    end
  end
end
