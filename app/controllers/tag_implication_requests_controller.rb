# frozen_string_literal: true

class TagImplicationRequestsController < ApplicationController
  before_action :member_only

  def new
  end

  def create
    @tag_implication_request = TagImplicationRequest.new(tir_params)
    @tag_implication_request.create

    if @tag_implication_request.invalid?
      render :action => "new"
    elsif @tag_implication_request.forum_topic
      redirect_to forum_topic_path(@tag_implication_request.forum_topic)
    else
      redirect_to tag_implication_path(@tag_implication_request.tag_relationship)
    end
  end

private

  def tir_params
    permitted = %i{antecedent_name consequent_name reason}
    permitted += [:skip_forum] if CurrentUser.is_admin?
    params.require(:tag_implication_request).permit(permitted)
  end
end
