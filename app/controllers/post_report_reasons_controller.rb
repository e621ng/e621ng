# frozen_string_literal: true

class PostReportReasonsController < ApplicationController
  respond_to :html
  before_action :admin_only


  def index
    @reasons = PostReportReason.order('id DESC')
    respond_with(@reasons)
  end

  def new
    @reason = PostReportReason.new
  end

  def destroy
    @reason = PostReportReason.find(params[:id])
    PostReportReason.transaction do
      @reason.destroy
      ModAction.log(:report_reason_delete, {reason: @reason.reason, user_id: @reason.creator_id})
    end
    respond_with(@reason)
  end

  def create
    PostReportReason.transaction do
      @reason = PostReportReason.create(reason_params)
      ModAction.log(:report_reason_create, {reason: @reason.reason})
    end
    flash[:notice] = @reason.valid? ? "Post report reason created" : @reason.errors.full_messages.join("; ")
    redirect_to post_report_reasons_path
  end

  def edit
    @reason = PostReportReason.find(params[:id])
  end

  def update
    @reason = PostReportReason.find(params[:id])
    PostReportReason.transaction do
      @reason.update(reason_params)
      ModAction.log(:report_reason_update, { reason: @reason.reason, reason_was: @reason.reason_before_last_save, description: @reason.description, description_was: @reason.description_before_last_save }) if @reason.valid?
    end
    flash[:notice] = @reason.valid? ? "Post report reason updated" : @reason.errors.full_messages.join("; ")
    redirect_to post_report_reasons_path
  end

  private

  def reason_params
    params.require(:post_report_reason).permit(%i[reason description])
  end
end
