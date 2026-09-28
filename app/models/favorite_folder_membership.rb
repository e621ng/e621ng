# frozen_string_literal: true

class FavoriteFolderMembership < ApplicationRecord
  belongs_to :user
  belongs_to :folder, class_name: "FavoriteFolder"
  belongs_to :favorite

  validates :favorite_id, uniqueness: true
  validate :folder_belongs_to_same_user
  validate :user_matches_favorite_owner
  validate :post_matches_favorite_post
  validate :favorite_created_at_matches_favorite

  private

  def folder_belongs_to_same_user
    return if folder.nil?
    errors.add(:folder, "must belong to you") if folder.user_id != user_id
  end

  # user_id/post_id/favorite_created_at are denormalized copies of the referenced
  # Favorite's own user_id/post_id/created_at, captured so folder pages never need to join
  # back into favorites. These validations guard against that copy ever drifting out of
  # sync with its source. Note: FavoriteFolderManager.move! writes via upsert, which (like
  # insert_all/update_all) bypasses AR validations entirely - this is enforced there by
  # construction instead (user_id/post_id/favorite_created_at are always read directly off
  # the already-loaded `user`/`favorite` objects, never independently supplied), so this
  # validation's real audience is any other write path: specs, console usage, and future
  # code.
  def user_matches_favorite_owner
    return if favorite.nil?
    errors.add(:user_id, "must match the favorite's owner") if favorite.user_id != user_id
  end

  def post_matches_favorite_post
    return if favorite.nil?
    errors.add(:post_id, "must match the favorite's post") if favorite.post_id != post_id
  end

  # favorite_created_at drifting from favorite.created_at wouldn't raise or fail loudly
  # anywhere else - it would just silently produce wrong "newest favorite first" folder
  # ordering forever, since folder pages sort/paginate by this column alone and never
  # cross-check it against favorites.created_at.
  #
  # Compared via this column's own type-cast, not naive != (and not a manual .round(6)
  # either - tried that first, and it doesn't match: Rails' own precision-aware casting
  # TRUNCATES sub-microsecond digits on assignment, while Time#round rounds to nearest,
  # so the two disagree whenever the truncated digits are >= half a microsecond).
  # favorite_created_at's column has an explicit Rails precision (6), so it's already
  # truncated the moment it's assigned; favorites.created_at's column doesn't declare
  # one, so its in-memory value keeps Ruby's full nanosecond Time precision until an
  # actual DB round-trip. Casting favorite.created_at through this attribute's own type
  # reproduces exactly what Rails already did to favorite_created_at, so the comparison
  # can't drift from whatever truncation rule Rails happens to use.
  def favorite_created_at_matches_favorite
    return if favorite.nil?
    casted = self.class.type_for_attribute(:favorite_created_at).cast(favorite.created_at)
    errors.add(:favorite_created_at, "must match the favorite's created_at") if casted != favorite_created_at
  end
end
