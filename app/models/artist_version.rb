class ArtistVersion < ApplicationRecord
  array_attribute :urls
  array_attribute :other_names

  belongs_to_updater
  user_status_counter :artist_edit_count, foreign_key: :updater_id
  belongs_to :artist
  delegate :visible?, :to => :artist

  module SearchMethods
    def for_user(user_id)
      where("updater_id = ?", user_id)
    end

    def search(params)
      q = super

      if params[:name].present?
        q = q.where("name like ? escape E'\\\\'", params[:name].to_escaped_for_sql_like)
      end

      q = q.where_user(:updater_id, :updater, params)

      if params[:artist_id].present?
        q = q.where(artist_id: params[:artist_id].split(",").map(&:to_i))
      end

      q = q.attribute_matches(:is_active, params[:is_active])

      if params[:ip_addr].present?
        q = q.where("updater_ip_addr <<= ?", params[:ip_addr])
      end

      if params[:order] == "name"
        q = q.order("artist_versions.name").default_order
      else
        q = q.apply_basic_order(params)
      end

      q
    end
  end

  extend SearchMethods

  def previous
    ArtistVersion.where("artist_id = ? and created_at < ?", artist_id, created_at).order("created_at desc").first
  end
end
