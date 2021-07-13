# frozen_string_literal: true

module ReleaseTools
  module Qa
    class IssuableSortByLabels
      attr_reader :issuables

      def initialize(issuables)
        @issuables = issuables
      end

      def sort_by_labels(*label_sets)
        sort(label_sets, issuables)
      end

      private

      def sort(criteria, unsorted)
        sorted = criteria.shift.each_with_object({}) do |element, hash|
          results = unsorted.select { |item| item.labels.include?(element) }
          unsorted -= results

          results = sort(criteria.dup, results) if criteria.any?

          hash[element] = results unless results.empty?
        end
        sorted[unmatched_label] = unsorted unless unsorted.empty?
        sorted
      end

      def unmatched_label
        'uncategorized'
      end
    end
  end
end
