# frozen_string_literal: true

class PaginatorComponent < ViewComponent::Base
  include IconHelper

  def initialize(records:)
    super()
    @records = records
    @mode = records.pagination_mode
    @mode = :sequential if @mode == :numbered && records.current_page >= records.max_numbered_pages
  end

  private

  attr_reader :records, :mode

  def last_page
    return nil if mode == :sequential
    @last_page ||= begin
      total = records.total_pages
      total.nil? ? nil : [total, records.max_numbered_pages].min
    end
  end

  def current_page
    @current_page ||= records.current_page
  end

  def display_class
    case mode
    when :sequential, :sequential_before, :sequential_after
      "sequential"
    when :numbered
      "numbered"
    else
      ""
    end
  end

  ##############################
  ###  Generic Nav Elements  ###
  ##############################

  def has_prev?
    return current_page > 1 if @mode == :numbered
    !records.is_first_page?
  end

  def prev_path
    return nav_params_for(current_page - 1) if @mode == :numbered
    nav_params_for("a#{records.first&.id}")
  end

  def has_next?
    return current_page < last_page if @mode == :numbered
    !records.is_last_page?
  end

  def next_path
    return nav_params_for(current_page + 1) if @mode == :numbered
    nav_params_for("b#{records.last&.id}")
  end

  ##############################
  ####  Numbered Paginator  ####
  ##############################

  def numbered_pages
    result = []
    result.push([1, "first"])

    left = current_page - 1
    right = current_page + 1

    # Shift window to the other side if we are near the edges
    right += 3 - left if left <= 3
    left -= right - last_page + 3 if right >= last_page - 3

    visible_pages = (left..right).select { |p| p > 1 && p < last_page }
    result.push([0, "spacer"]) if visible_pages.first && visible_pages.first > 2
    visible_pages.each do |page|
      result.push([page, ""])
    end
    result.push([0, "spacer"]) if visible_pages.last && visible_pages.last < last_page - 1

    result.push([last_page, "last"]) unless last_page <= 1
    result
  end

  def nav_params_for(page)
    query_params = params.except(:id).merge(page: page).permit!
    url_for(query_params)
  end
end
