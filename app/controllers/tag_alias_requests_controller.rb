# frozen_string_literal: true

class TagAliasRequestsController < ApplicationController
  before_action :member_only
  before_action :ensure_lockdown_disabled

  def new
  end

  def create
    @tag_alias_request = TagAliasRequest.new(tar_params)
    @tag_alias_request.create

    if @tag_alias_request.invalid?
      render :action => "new"
    elsif @tag_alias_request.forum_topic
      redirect_to forum_topic_path(@tag_alias_request.forum_topic)
    else
      redirect_to tag_alias_path(@tag_alias_request.tag_relationship)
    end
  end

  private

  def tar_params
    permitted = %i[antecedent_name consequent_name reason]
    permitted += [:skip_forum] if CurrentUser.is_admin?
    params.require(:tag_alias_request).permit(permitted)
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.aiburs_disabled? && !CurrentUser.is_staff?
  end
end
