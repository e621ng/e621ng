# frozen_string_literal: true

class PostFlagReasonsController < ApplicationController
  respond_to :html
  before_action :admin_only

  def index
    @reasons = PostFlagReason.ordered
    respond_with(@reasons)
  end

  def new
    @reason = PostFlagReason.new
    @reason.index = PostFlagReason.maximum(:index).to_i + 1
  end

  def edit
    @reason = PostFlagReason.find(params[:id])
  end

  def create
    PostFlagReason.transaction do
      @reason = PostFlagReason.create(reason_params)
      ModAction.log(:flag_reason_create, { reason: @reason.reason, text: @reason.text })
    end
    flash[:notice] = @reason.valid? ? "Post flag reason created" : @reason.errors.full_messages.join("; ")
    redirect_to post_flag_reasons_path
  end

  def update
    @reason = PostFlagReason.find(params[:id])
    PostFlagReason.transaction do
      @reason.update(reason_params)
      ModAction.log(:flag_reason_update, { reason: @reason.reason, reason_was: @reason.reason_before_last_save, text: @reason.text, text_was: @reason.text_before_last_save }) if @reason.valid?
    end
    flash[:notice] = @reason.valid? ? "Post flag reason updated" : @reason.errors.full_messages.join("; ")
    redirect_to post_flag_reasons_path
  end

  def destroy
    @reason = PostFlagReason.find(params[:id])
    PostFlagReason.transaction do
      @reason.destroy
      ModAction.log(:flag_reason_delete, { reason: @reason.reason })
    end
    respond_with(@reason)
  end

  def clear_cache
    PostFlagReason.invalidate_cache
    flash[:notice] = "Post flag reason cache cleared"
    redirect_to post_flag_reasons_path
  end

  private

  def reason_params
    params.require(:post_flag_reason).permit(%i[name reason text needs_explanation needs_parent_id needs_staff_reason target_date target_date_kind target_tag index])
  end
end
