# frozen_string_literal: true

# Loads the data artists/show needs beyond @artist.
module ArtistShowPage
  extend ActiveSupport::Concern

  private

  def load_artist_show_page
    @post_set = PostSets::Post.new(@artist.name, 1, limit: 10)
    return unless CurrentUser.user.is_staff?
    @staff_wikis = StaffWiki.joins(:references).where(references: { related_type: "Artist", related_id: @artist.id }).distinct
  end
end
