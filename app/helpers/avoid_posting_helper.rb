# frozen_string_literal: true

module AvoidPostingHelper
  def format_avoid_posting_list
    avoid_postings = AvoidPosting.active.order("artist_name ASC").group_by(&:header)
    text = ""
    avoid_postings.each do |header, entries|
      text += "h2. #{header} [##{anchor(header)}]\n"
      entries.each do |dnp|
        text += "* #{dnp.all_names}"
        if dnp.details.present?
          text += " - #{dnp.details}"
        end
        text += "\n"
      end
      text += "\n"
    end
    format_text(text)
  end

  private

  def anchor(header)
    case header
    when "#"
      "number"
    when "?"
      "other"
    else
      header.downcase
    end
  end
end
