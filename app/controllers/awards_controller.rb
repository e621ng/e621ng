# frozen_string_literal: true

class AwardsController < ApplicationController
  before_action :janitor_only, only: %i[create destroy]
  respond_to :html
  respond_to :json, only: %i[index]
  helper_method :search_params

  def index
    @awards = Award.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@awards) do |format|
      format.html { @awards = @awards.includes(:award_type, :user, :creator) }
    end
  end

  def new
    @award = Award.new(award_params)
  end

  def create
    @award = Award.new(award_params)
    @award.creator = CurrentUser.user
    if @award.save
      redirect_to user_path(@award.user_id), notice: "Award given"
    else
      redirect_back fallback_location: awards_path, notice: @award.errors.full_messages.join("; ")
    end
  end

  def destroy
    @award = Award.find(params[:id])
    raise User::PrivilegeError unless @award.can_destroy?(CurrentUser.user)

    @award.destroy
    redirect_back fallback_location: awards_path, notice: "Award revoked"
  end

  private

  def award_params
    permitted = %i[award_type_id reason]
    permitted += %i[user_id user_name]
    params.fetch(:award, {}).permit(permitted)
  end

  def search_params
    permit_search_params %i[user_name user_id award_type_id creator_name]
  end
end
