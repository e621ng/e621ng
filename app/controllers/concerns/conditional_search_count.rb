# frozen_string_literal: true

# Provides utilities for conditionally enabling pagination counts based on search narrowing.
# This prevents expensive COUNT queries on broad searches that would scan entire tables.
module ConditionalSearchCount
  extend ActiveSupport::Concern

  # Determines whether the search should include a count based on narrowing parameters.
  #
  # @param narrowing [Array<Symbol>] Search params that narrow results (id, name, etc.)
  # @param truthy [Array<Symbol>] Boolean params that narrow when true
  # @param falsy [Array<Symbol>] Boolean params that narrow when false
  # @return [Hash, nil] Returns params[:search] if narrowing detected, nil otherwise
  def search_count_params(narrowing: [], truthy: [], falsy: [])
    has_narrowing_search = narrowing.any? { |param| params[:search]&.dig(param).present? }
    has_narrowing_search ||= truthy.any? { |param| params[:search]&.dig(param).to_s == "true" }
    has_narrowing_search ||= falsy.any? { |param| params[:search]&.dig(param).to_s == "false" }

    has_narrowing_search ? params[:search] : nil
  end
end
