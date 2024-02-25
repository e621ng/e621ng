# frozen_string_literal: true

class ArtistUrlsController < ApplicationController
  respond_to :json, :html
  before_action :member_only, except: [:index]

  def index
    @artist_urls = ArtistUrl.includes(:artist).search(search_params).paginate(params[:page], limit: params[:limit], search_count: params[:search])
    respond_with(@artist_urls) do |format|
      format.json { render json: @artist_urls.to_json(include: :artist) }
    end
  end
end
