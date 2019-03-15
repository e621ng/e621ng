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
      ModAction.log("deleted report reason #{@reason.reason} by #{CurrentUser.id}", :delete_report_reason)
    end
    respond_with(@reason)
  end

  def create
    PostReportReason.transaction do
      @reason = PostReportReason.create(reason_params)
      ModAction.log("Created new report reason #{@reason.reason} by #{CurrentUser.id}", :new_report_reason) if @reason.valid?
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
      ModAction.log("Updated report reason #{@reason.reason} by #{CurrentUser.id}", :update_report_reason) if @reason.valid?
    end
    flash[:notice] = @reason.valid? ? 'Post report reason updated' : @reason.errors.full_messages.join('; ')
    redirect_to post_report_reasons_path
  end

  private

  def reason_params
    params.require(:post_report_reason).permit(%i[reason description])
  end
end