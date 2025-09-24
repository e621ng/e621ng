# frozen_string_literal: true

class ModActionsController < ApplicationController
  respond_to :html, :json

  def index
    @mod_actions = ModActionDecorator.decorate_collection(
      ModAction.visible(CurrentUser.user).includes(:creator).search(search_params).paginate(params[:page], limit: params[:limit]),
    )
    respond_with(@mod_actions)
  end

  def show
    @mod_action = ModAction.find(params[:id])
    check_permission(@mod_action)
    respond_with(@mod_action) do |fmt|
      fmt.html { redirect_to mod_actions_path(search: { id: @mod_action.id }) }
    end
  end

  def check_permission(mod_action)
    raise(User::PrivilegeError) unless mod_action.can_view?(CurrentUser.user)
  end
end
