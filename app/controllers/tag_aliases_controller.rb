# frozen_string_literal: true

class TagAliasesController < ApplicationController
  before_action :admin_only, except: [:index, :show, :destroy]
  respond_to :html, :json, :js

  def show
    @tag_alias = TagAlias.find(params[:id])
    respond_with(@tag_alias)
  end

  def edit
    @tag_alias = TagAlias.find(params[:id])
  end

  def update
    @tag_alias = TagAlias.find(params[:id])

    if @tag_alias.editable_by?(CurrentUser.user)
      update_params = tag_alias_params
      unless @tag_alias.is_pending?
        update_params = update_params.except(:antecedent_name, :consequent_name)
      end
      @tag_alias.update(update_params)
    end

    respond_with(@tag_alias)
  end

  def index
    @tag_aliases = TagAlias.includes(:antecedent_tag, :consequent_tag, :approver).search(search_params).paginate(params[:page], :limit => params[:limit])
    respond_with(@tag_aliases)
  end

  def destroy
    @tag_alias = TagAlias.find(params[:id])
    return access_denied unless @tag_alias.deletable_by?(CurrentUser.user)
    @tag_alias.reject!
    respond_with(@tag_alias, location: tag_aliases_path)
  end

  def approve
    @tag_alias = TagAlias.find(params[:id])
    return access_denied unless @tag_alias.approvable_by?(CurrentUser.user)
    @tag_alias.approve!(approver: CurrentUser.user)
    respond_with(@tag_alias, location: tag_alias_path(@tag_alias))
  end

  private

  def tag_alias_params
    params.require(:tag_alias).permit(%i[antecedent_name consequent_name forum_topic_id])
  end
end
