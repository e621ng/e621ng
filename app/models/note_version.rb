class NoteVersion < ApplicationRecord
  user_status_counter :note_count, foreign_key: :updater_id
  belongs_to_updater
  scope :for_user, ->(user_id) {where("updater_id = ?", user_id)}

  def self.search(params)
    q = super

    if params[:updater_id]
      q = q.where(updater_id: params[:updater_id].split(",").map(&:to_i))
    end

    if params[:post_id]
      q = q.where(post_id: params[:post_id].split(",").map(&:to_i))
    end

    if params[:note_id]
      q = q.where(note_id: params[:note_id].split(",").map(&:to_i))
    end

    q = q.attribute_matches(:is_active, params[:is_active])
    q = q.attribute_matches(:body, params[:body_matches])

    q.apply_default_order(params)
  end

  def previous
    NoteVersion.where("note_id = ? and updated_at < ?", note_id, updated_at).order("updated_at desc").first
  end
end
