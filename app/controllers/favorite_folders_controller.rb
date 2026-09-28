# frozen_string_literal: true

class FavoriteFoldersController < ApplicationController
  before_action :member_only
  before_action :ensure_lockdown_disabled
  before_action :reject_malformed_folder_id_params
  respond_to :json, only: %i[create update move]
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

  def move
    folder = CurrentUser.user.favorite_folders.find(params[:id])
    destination_parent_id = params[:parent_id].presence&.to_i
    moved = FavoriteFolderManager.move_folder!(user: CurrentUser.user, folder: folder, destination_parent_id: destination_parent_id)
    render json: { id: moved.id, parent_id: moved.parent_id }
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

  def ensure_lockdown_disabled
    render_expected_error(403, "Favorites are disabled") if Security::Lockdown.favorites_disabled? && !CurrentUser.is_staff?
  end

  def reject_malformed_folder_id_params
    return if scalar_or_blank?(params[:id]) && scalar_or_blank?(params[:parent_id])
    render_expected_error(400, "Invalid folder id parameter")
  end

  def scalar_or_blank?(value)
    value.nil? || value.is_a?(String) || value.is_a?(Numeric)
  end
end
