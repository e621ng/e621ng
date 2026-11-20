# frozen_string_literal: true

# Loads the data artists/show needs beyond @artist.
module ArtistShowPage
  extend ActiveSupport::Concern

  private

  def load_artist_show_page
    @post_set = PostSets::Post.new(@artist.name, 1, limit: 10)
    load_alias_leftovers
    return unless CurrentUser.user.is_staff? && @artist.persisted?
    @staff_wikis = StaffWiki.joins(:references).where(references: { related_type: "Artist", related_id: @artist.id }).distinct
  end

  # Aliasing onto an existing artist leaves the antecedent's entry behind, to be merged by hand.
  def load_alias_leftovers
    @leftover_artists = Artist.where(name: TagAlias.active.where(consequent_name: @artist.name).select(:antecedent_name)).order(:name).to_a
    @left_behind_alias = @artist.tag&.antecedent_alias if @artist.persisted?
  end
end
