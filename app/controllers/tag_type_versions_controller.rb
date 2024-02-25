# frozen_string_literal: true

class TagTypeVersionsController < ApplicationController
  respond_to :html, :json

  def index
    @tag_versions = TagTypeVersion.search(params[:search]).paginate(params[:page], limit: params[:limit])

    respond_with(@tag_versions)
  end
end
