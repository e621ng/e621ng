# frozen_string_literal: true

class ArtistsShortController < ApplicationController
  include ArtistShowPage

  def show
    name = Artist.normalize_name(params[:name])
    raise ActiveRecord::RecordNotFound, "Artist not found" if name.blank?

    # Aliases first: the antecedent's artist row can outlive the alias.
    alias_name = TagAlias.active.where(antecedent_name: name).pick(:consequent_name)
    return redirect_to(short_artist_path(alias_name)) if alias_name
    return redirect_to(short_artist_path(name)) if name != params[:name]

    @artist = Artist.find_by(name: name) || artist_stub(name)
    load_artist_show_page
  end

  # Fall back to app/views/artists, which uses unqualified partials.
  def self.local_prefixes
    [controller_path, "artists"]
  end
  private_class_method :local_prefixes

  private

  # Artist-category tags without an artist entry get a placeholder page offering to create one.
  def artist_stub(name)
    tag = Tag.find_by(name: name)
    raise ActiveRecord::RecordNotFound, "Artist not found" unless tag&.category == Tag.categories.artist
    Artist.new(name: name).tap { |artist| artist.association(:tag).target = tag }
  end
end
