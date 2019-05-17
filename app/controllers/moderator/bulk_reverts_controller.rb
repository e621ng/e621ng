module Moderator
  class BulkRevertsController < ApplicationController
    before_action :moderator_only
    before_action :init_constraints
    helper PostVersionsHelper
    rescue_from BulkRevert::ConstraintTooGeneralError, :with => :tag_constraint_too_general

    def new
    end

    def create
      @bulk_revert = BulkRevert.new(@constraints)

      if params[:commit] == "Test"
        @bulk_revert.preview
        render action: "new"
      else
        BulkRevertJob.perform_later(CurrentUser.id, @constraints)
        flash[:notice] = "Reverts queued"
        redirect_to new_moderator_bulk_revert_path
      end
    end

  private

    def init_constraints
      @constraints = params.fetch(:constraints, {}).permit(%w[user_name user_id added_tags removed_tags min_version_id max_version_id])
    end

    def tag_constraint_too_general
      flash[:notice] = "Your tag constraints are too general; try adding min and max version ids"
      render action: "new"
    end
  end
end
