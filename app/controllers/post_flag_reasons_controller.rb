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
      ModAction.log(:flag_reason_create, { reason: @reason.reason, text: @reason.text }) if @reason.valid?
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
    if @reason.name == Setting.ai_flag_reason
      flash[:alert] = "This flag reason is used for the automatic AI post flagging"
      redirect_to post_flag_reasons_path
      return
    end
    PostFlagReason.transaction do
      @reason.destroy
      ModAction.log(:flag_reason_delete, { reason: @reason.reason })
    end
    flash[:notice] = @reason.destroyed? ? "Post flag reason deleted" : @reason.errors.full_messages.join("; ")
    respond_with(@reason)
  end

  def clear_cache
    PostFlagReason.invalidate_cache
    flash[:notice] = "Post flag reason cache cleared"
    redirect_to post_flag_reasons_path
  end

  def set_ai_flag_reason
    ai_params = ai_flag_reason_params

    reason = PostFlagReason.by_name(ai_params[:reason].to_s)
    if reason.blank? || reason.needs_parent_id?
      flash[:alert] = "Flag reason doesn't exist or is not usable for AI flagging"
      redirect_to post_flag_reasons_path
      return
    end

    ai_flag_was_enabled = Setting.automatic_ai_check?
    Setting.automatic_ai_check = ActiveModel::Type::Boolean.new.cast(ai_params[:automatic_ai_check])
    ai_flag_enabled = Setting.automatic_ai_check?

    Setting.ai_flag_reason = reason.name

    if ai_flag_was_enabled != ai_flag_enabled
      flash[:notice] = "Automatic AI post flagging #{ai_flag_enabled ? 'enabled' : 'disabled'}"
    end
    redirect_to post_flag_reasons_path
  end

  private

  def reason_params
    params.require(:post_flag_reason).permit(%i[name reason text needs_explanation needs_parent_id needs_staff_reason target_date target_date_kind target_tag index])
  end

  def ai_flag_reason_params
    params.require(:ai_flag_reason).permit(%i[automatic_ai_check reason])
  end
end
