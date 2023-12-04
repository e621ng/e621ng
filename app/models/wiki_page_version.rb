class WikiPageVersion < ApplicationRecord
  array_attribute :other_names
  belongs_to :wiki_page
  belongs_to_updater
  user_status_counter :wiki_edit_count, foreign_key: :updater_id
  belongs_to :artist, optional: true
  delegate :visible?, to: :wiki_page

  module SearchMethods
    def for_user(user_id)
      where("updater_id = ?", user_id)
    end

    def search(params)
      q = super

      q = q.where_user(:updater_id, :updater, params)

      if params[:wiki_page_id].present?
        q = q.where("wiki_page_id = ?", params[:wiki_page_id].to_i)
      end

      q = q.attribute_matches(:title, params[:title])
      q = q.attribute_matches(:body, params[:body])
      q = q.attribute_matches(:is_locked, params[:is_locked])
      q = q.attribute_matches(:is_deleted, params[:is_deleted])

      if params[:ip_addr].present?
        q = q.where("updater_ip_addr <<= ?", params[:ip_addr])
      end

      q.apply_basic_order(params)
    end
  end

  extend SearchMethods

  def pretty_title
    title.tr("_", " ")
  end

  def previous
    return @previous if defined?(@previous)
    @previous = WikiPageVersion.where("wiki_page_id = ? and id < ?", wiki_page_id, id).order("id desc").first
  end

  def category_id
    Tag.category_for(title)
  end
end
