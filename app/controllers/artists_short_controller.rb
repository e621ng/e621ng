# frozen_string_literal: true

class ArtistsShortController < ApplicationController
  include ArtistShowPage

  def show
    name = Artist.normalize_name(params[:name])
    raise ActiveRecord::RecordNotFound, "Artist not found" if name.blank?
    bypass = params[:redirect] == "no" ? { redirect: "no" } : {}

    # Aliases first: the antecedent's artist row can outlive the alias.
    # `?redirect=no` reaches such leftover rows instead.
    alias_name = TagAlias.active.where(antecedent_name: name).pick(:consequent_name)
    @artist = Artist.find_by(name: name) if alias_name && bypass.present?
    return redirect_to(short_artist_path(alias_name, from: name)) if alias_name && !@artist
    return redirect_to(short_artist_path(name, **bypass)) if name != params[:name]

    @artist ||= Artist.find_by(name: name) || artist_stub(name)
    load_artist_show_page
    @redirected_from = redirected_from
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

  # Only trust `from` when it really is aliased here, so the URL can't inject arbitrary names.
  def redirected_from
    from = Artist.normalize_name(params[:from])
    return if from.blank?
    from if TagAlias.active.where(antecedent_name: from, consequent_name: @artist.name).exists?
  end
end
