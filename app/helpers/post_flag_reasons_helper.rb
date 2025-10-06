# frozen_string_literal: true

module PostFlagReasonsHelper
  def hierarchical_flag_reasons_for_select(current_reason = nil)
    # Get all reasons except the current one being edited (to prevent self-parenting)
    reasons = PostFlagReason.structured.ordered
    reasons = reasons.where.not(id: current_reason.id) if current_reason&.persisted?

    build_hierarchical_options(reasons, current_reason)
  end

  private

  def build_hierarchical_options(reasons, current_reason = nil, level = 0)
    options = []

    reasons.each do |reason |
      # Skip if this would create a circular reference
      next if current_reason && would_create_cycle?(current_reason, reason)

      # Add indentation for child levels using em-spaces
      prefix = "\u2003" * level
      display_name = "#{prefix}#{reason.reason}"

      options << [display_name, reason.id]

      # Recursively add children
      if reason.children.any?
        options.concat(build_hierarchical_options(reason.children, current_reason, level + 1))
      end
    end

    options
  end

  def would_create_cycle?(current_reason, potential_parent)
    return false unless current_reason&.persisted?

    # Check if the potential parent is actually a descendant of current_reason
    check_descendant = potential_parent
    while check_descendant
      return true if check_descendant.id == current_reason.id
      check_descendant = check_descendant.parent
    end

    false
  end
end
