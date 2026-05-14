# frozen_string_literal: true

class AppealsController < ApplicationController
  respond_to :html, :json, except: %i[create new]
  before_action :member_only, except: %i[index]
  before_action :janitor_only, only: %i[update claim unclaim]

  def index
    @appeals = Appeal
               .includes(:creator, :accused, :claimant)
               .visible(CurrentUser.user)
               .search(search_params)
               .paginate(params[:page], limit: params[:limit])
    preload_appeal_contents(@appeals)
    respond_with(@appeals)
  end

  def show
    @appeal = Appeal.find(params[:id])
    check_permission(@appeal)
    respond_with(@appeal)
  end

  def new
    @appeal = Appeal.new(qtype: params[:qtype], disp_id: params[:disp_id])
    @existing_similar = Appeal
                        .visible(CurrentUser.user)
                        .where({
                          creator_id: CurrentUser.id,
                          qtype: @appeal.qtype,
                          status: "pending",
                          created_at: 1.week.ago..,
                        })
                        .order(created_at: :desc)
                        .limit(5)

    check_new_permission(@appeal)
  end

  def create
    @appeal = Appeal.new(appeal_params)
    check_new_permission(@appeal)
    if @appeal.valid?
      @appeal.save
      redirect_to(appeal_path(@appeal))
    else
      render action: "new"
    end
  end

  def update
    @appeal = Appeal.find(params[:id])

    raise User::PrivilegeError unless @appeal.can_view?(CurrentUser.user) && @appeal.can_handle?(CurrentUser.user)

    if @appeal.claimant_id.present? && @appeal.claimant_id != CurrentUser.id && !params[:force_claim].to_s.truthy?
      flash[:notice] = "Appeal has already been claimed by somebody else, submit again to force"
      redirect_to appeal_path(@appeal, force_claim: "true")
      return
    end

    appeal_params = update_appeal_params
    @appeal.transaction do
      @appeal.handler_id = CurrentUser.id
      @appeal.claimant_id = CurrentUser.id
      @appeal.update(appeal_params)
    end

    if @appeal.valid?
      not_changed = appeal_params[:send_update_dmail].to_s.truthy? && (!@appeal.saved_change_to_response? && !@appeal.saved_change_to_status?)
      flash[:notice] = "Not sending update, no changes" if not_changed
    end

    respond_with(@appeal)
  end

  def claim
    @appeal = Appeal.find(params[:id])

    raise User::PrivilegeError unless @appeal.can_view?(CurrentUser.user) && @appeal.can_claim?(CurrentUser.user)

    if @appeal.claimant.nil?
      @appeal.claim!
      return respond_with(@appeal)
    end
    flash[:notice] = "Appeal already claimed"
    respond_with(@appeal)
  end

  def unclaim
    @appeal = Appeal.find(params[:id])

    raise User::PrivilegeError unless @appeal.can_view?(CurrentUser.user) && @appeal.can_claim?(CurrentUser.user)

    if @appeal.claimant.nil?
      flash[:notice] = "Appeal not claimed"
      return respond_with(@appeal)
    elsif @appeal.claimant.id != CurrentUser.id
      flash[:notice] = "Appeal not claimed by you"
      return respond_with(@appeal)
    elsif @appeal.approved?
      flash[:notice] = "Cannot unclaim approved appeal"
      return respond_with(@appeal)
    end
    @appeal.unclaim!
    flash[:notice] = "Claim removed"
    respond_with(@appeal)
  end

  private

  def preload_appeal_contents(appeals)
    appeals.group_by(&:qtype).each_value do |group|
      model = group.first.model
      next if model.nil?
      ids = group.map(&:disp_id).compact
      content_map = model.where(id: ids).index_by(&:id)
      group.each { |t| t.instance_variable_set(:@content, content_map[t.disp_id]) }
    end
  end

  def appeal_params
    params.require(:appeal).permit(%i[qtype disp_id reason])
  end

  def update_appeal_params
    params.require(:appeal).permit(%i[response status send_update_dmail])
  end

  def search_params
    current_search_params = params.fetch(:search, {})
    permitted_params = %i[qtype status order]
    permitted_params += %i[creator_id] if CurrentUser.is_staff? || (current_search_params[:creator_id].present? && current_search_params[:creator_id].to_i == CurrentUser.id)
    permitted_params += %i[disp_id creator_name accused_name accused_id claimant_id claimant_name reason] if CurrentUser.is_staff?
    permit_search_params permitted_params
  end

  def check_new_permission(appeal)
    raise(User::PrivilegeError) unless appeal.can_create_for?(CurrentUser.user)
  end

  def check_permission(appeal)
    raise(User::PrivilegeError) unless appeal.can_view?(CurrentUser.user)
  end
end
