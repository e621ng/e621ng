# frozen_string_literal: true

class StaffWikiVersion < ApplicationRecord
  belongs_to :staff_wiki
  belongs_to_updater

  module SearchMethods
    def search(params)
      q = super

      q = q.where_user(:updater_id, :updater, params)
      q = q.where("staff_wiki_id = ?", ParseValue.safe_id(params[:staff_wiki_id])) if params[:staff_wiki_id].present?
      q = q.attribute_matches(:title, params[:title])
      q = q.attribute_matches(:body, params[:body])
      q = q.where("updater_ip_addr <<= ?", params[:ip_addr]) if params[:ip_addr].present?

      q.apply_basic_order(params)
    end
  end

  extend SearchMethods

  def pretty_title
    title.tr("_", " ")
  end

  def previous
    return @previous if defined?(@previous)

    @previous = StaffWikiVersion.where("staff_wiki_id = ? and id < ?", staff_wiki_id, id).order("id desc").first
  end
end
