# frozen_string_literal: true

class PoolOrdersController < ApplicationController
  respond_to :html, :json
  before_action :member_only

  def edit
    @pool = Pool.find(params[:pool_id])
    respond_with(@pool)
  end
end
