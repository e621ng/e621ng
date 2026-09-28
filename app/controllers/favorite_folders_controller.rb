# frozen_string_literal: true

class FavoriteFoldersController < ApplicationController
  before_action :member_only
  respond_to :json, only: %i[create update]
  respond_to :html, only: [:destroy]

  def create
    folder = FavoriteFolderManager.create!(user: CurrentUser.user, name: params[:name], parent: parent_folder)
    render json: folder
  rescue FavoriteFolderManager::Error, ActiveRecord::RecordNotFound => e
    render_expected_error(422, e.message)
  end

  def update
    folder = CurrentUser.user.favorite_folders.find(params[:id])
    FavoriteFolderManager.rename!(user: CurrentUser.user, folder: folder, name: params[:name])
    render json: folder
  rescue FavoriteFolderManager::Error, ActiveRecord::RecordNotFound => e
    render_expected_error(422, e.message)
  end

  def destroy
    folder = CurrentUser.user.favorite_folders.find(params[:id])
    parent_id = folder.parent_id # captured before delete! runs, so we always know where to redirect

    FavoriteFolderManager.delete!(user: CurrentUser.user, folder: folder)
    redirect_to favorites_path(folder_id: parent_id), notice: "Folder deleted"
  rescue FavoriteFolderManager::Error => e
    redirect_to favorites_path(folder_id: folder.parent_id), alert: e.message
  rescue ActiveRecord::RecordNotFound => e
    render_expected_error(404, e.message)
  end

  private

  def parent_folder
    return nil if params[:parent_id].blank?
    CurrentUser.user.favorite_folders.find(params[:parent_id])
  end
end
