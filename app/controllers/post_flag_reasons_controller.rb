# frozen_string_literal: true

class PostFlagReasonsController < ApplicationController
  respond_to :html
  before_action :janitor_only

  def index
    @reasons = PostFlagReason.ordered
    respond_with(@reasons)
  end

  def new
    @reason = PostFlagReason.new
    @reason.index ||= PostFlagReason.maximum(:index).to_i + 1
  end

  def edit
    @reason = PostFlagReason.find(params[:id])
  end

  def create
    PostFlagReason.transaction do
      @reason = PostFlagReason.create(reason_params)
      # If your ModAction keys include logging for flag reason changes, you can add it here similarly to report reasons.
    end
    flash[:notice] = @reason.valid? ? "Post flag reason created" : @reason.errors.full_messages.join("; ")
    redirect_to post_flag_reasons_path
  end

  def update
    @reason = PostFlagReason.find(params[:id])
    PostFlagReason.transaction do
      @reason.update(reason_params)
    end
    flash[:notice] = @reason.valid? ? "Post flag reason updated" : @reason.errors.full_messages.join("; ")
    redirect_to post_flag_reasons_path
  end

  def destroy
    @reason = PostFlagReason.find(params[:id])
    PostFlagReason.transaction do
      @reason.destroy
    end
    respond_with(@reason)
  end

  private

  def reason_params
    params.require(:post_flag_reason).permit(%i[name reason text require_explanation parent index type])
  end
end
