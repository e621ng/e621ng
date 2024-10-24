# frozen_string_literal: true

class TagImplicationsController < ApplicationController
  before_action :admin_only, except: [:index, :show, :destroy, :update, :approve]
  respond_to :html, :json, :js

  def show
    @tag_implication = TagImplication.find(params[:id])
    respond_with(@tag_implication)
  end

  def edit
    @tag_implication = TagImplication.find(params[:id])
  end

  def update
    @tag_implication = TagImplication.find(params[:id])

    if @tag_implication.editable_by?(CurrentUser.user)
      @tag_implication.update(tag_implication_params)
      respond_with(@tag_implication)
    else
      access_denied
    end
  end

  def index
    @tag_implications = TagImplication.includes(:antecedent_tag, :consequent_tag, :approver).search(search_params).paginate(params[:page], :limit => params[:limit])
    respond_with(@tag_implications)
  end

  def destroy
    @tag_implication = TagImplication.find(params[:id])

    if @tag_implication.deletable_by?(CurrentUser.user)
      @tag_implication.reject!
      if @tag_implication.errors.any?
        flash[:notice] = @tag_implication.errors.full_messages.join('; ')
        redirect_to(tag_implications_path)
        return
      end
      respond_with(@tag_implication) do |format|
        format.html do
          flash[:notice] = "Tag implication was deleted"
          redirect_to(tag_implications_path)
        end
      end
    else
      access_denied
    end
  end

  def approve
    @tag_implication = TagImplication.find(params[:id])

    if @tag_implication.approvable_by?(CurrentUser.user)
      @tag_implication.approve!(approver: CurrentUser.user)
      respond_with(@tag_implication, :location => tag_implication_path(@tag_implication))
    else
      access_denied
    end
  end

private

  def tag_implication_params
    params.require(:tag_implication).permit(%i[antecedent_name consequent_name forum_topic_id])
  end
end
