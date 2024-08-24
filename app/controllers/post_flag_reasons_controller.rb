# frozen_string_literal: true

class PostFlagReasonsController < ApplicationController
  before_action :admin_only, except: %i[index]
  respond_to :html, :json
  respond_to :js, only: %i[reorder]

  def index
    @reasons = PostFlagReason.ordered
    respond_with(@reasons)
  end

  def new
    @reason = PostFlagReason.new
  end

  def edit
    @reason = PostFlagReason.find(params[:id])
  end

  def create
    @reason = PostFlagReason.create(reason_params)
    flash[:notice] = @reason.valid? ? "Post flag reason created" : @reason.errors.full_messages.join("; ")
    redirect_to(post_flag_reasons_path)
  end

  def update
    @reason = PostFlagReason.find(params[:id])
    @reason.update(reason_params)
    flash[:notice] = @reason.valid? ? "Post flag reason updated" : @reason.errors.full_messages.join("; ")
    redirect_to(post_flag_reasons_path)
  end

  def destroy
    @reason = PostFlagReason.find(params[:id])
    @reason.destroy
    respond_with(@reason)
  end

  def order
    @reasons = PostFlagReason.ordered
  end

  def reorder
    return render_expected_error(422, "Error: No post flag reasons provided") unless params[:_json].is_a?(Array) && params[:_json].any?
    changes = 0
    PostFlagReason.transaction do
      params[:_json].each do |data|
        reason = PostFlagReason.find(data[:id])
        next if reason.order == data[:order].to_i
        reason.update_column(:order, data[:order])
        changes += 1
      end

      reasons = PostFlagReason.all
      if reasons.any?(&:invalid?)
        errors = []
        reasons.each do |reason|
          errors << { id: reason.id, name: reason.name, message: reason.errors.full_messages.join("; ") } if !reason.valid? && reason.errors.any?
        end
        render(json: { success: false, errors: errors }, status: 422)
        raise(ActiveRecord::Rollback)
      else
        PostFlagReason.log_reorder(changes) if changes != 0
        respond_to do |format|
          format.json { head(204) }
          format.js do
            render(json: { html: render_to_string(partial: "post_flag_reasons/table", locals: { reasons: PostFlagReason.ordered }) })
          end
        end
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_expected_error(422, "Error: Post flag reason not found")
  end

  private

  def reason_params
    params.require(:post_flag_reason).permit(%i[name reason text parent])
  end
end
