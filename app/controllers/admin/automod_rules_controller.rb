# frozen_string_literal: true

module Admin
  class AutomodRulesController < ApplicationController
    before_action :admin_only
    before_action :set_rule, only: %i[edit update destroy]
    respond_to :html

    def index
      @automod_rules = AutomodRule.order(:name).paginate(params[:page])
    end

    def new
      @automod_rule = AutomodRule.new
    end

    def create
      @automod_rule = AutomodRule.new(automod_rule_params)
      @automod_rule.creator = CurrentUser.user
      if @automod_rule.save
        redirect_to admin_automod_rules_path, notice: "Automod rule created."
      else
        render :new
      end
    end

    def edit; end

    def update
      if @automod_rule.update(automod_rule_params)
        redirect_to admin_automod_rules_path, notice: "Automod rule updated."
      else
        render :edit
      end
    end

    def destroy
      @automod_rule.destroy
      redirect_to admin_automod_rules_path, notice: "Automod rule deleted."
    end

    private

    def set_rule
      @automod_rule = AutomodRule.find(params[:id])
    end

    def automod_rule_params
      params.require(:automod_rule).permit(:name, :description, :regex, :enabled)
    end
  end
end
