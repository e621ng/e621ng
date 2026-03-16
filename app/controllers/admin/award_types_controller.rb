# frozen_string_literal: true

module Admin
  class AwardTypesController < ApplicationController
    before_action :admin_only
    before_action :set_award_type, only: %i[edit update destroy]
    respond_to :html

    def index
      @award_types = AwardType.order(:name).paginate(params[:page])
    end

    def new
      @award_type = AwardType.new
    end

    def edit
    end

    def create
      @award_type = AwardType.new(award_type_params)
      @award_type.creator = CurrentUser.user
      if @award_type.save
        redirect_to admin_award_types_path, notice: "Award type created"
      else
        render :new
      end
    end

    def update
      if @award_type.update(award_type_params)
        redirect_to admin_award_types_path, notice: "Award type updated"
      else
        render :edit
      end
    end

    def destroy
      @award_type.destroy
      redirect_to admin_award_types_path, notice: "Award type deleted"
    end

    private

    def set_award_type
      @award_type = AwardType.find(params[:id])
    end

    def award_type_params
      params.require(:award_type).permit(:name, :description, :icon_file)
    end
  end
end
