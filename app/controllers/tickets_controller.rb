# frozen_string_literal: true

class TicketsController < ApplicationController
  respond_to :html, :json, except: %i[create new]
  before_action :member_only, except: %i[index]
  before_action :moderator_only, only: %i[update edit claim unclaim]

  def index
    @tickets = Ticket.visible(CurrentUser.user).search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@tickets)
  end

  def new
    @ticket = Ticket.new(qtype: params[:qtype], disp_id: params[:disp_id])
    check_new_permission(@ticket)
  end

  def create
    @ticket = Ticket.new(ticket_params)
    check_new_permission(@ticket)
    if @ticket.valid?
      @ticket.save
      @ticket.push_pubsub("create")
      redirect_to(ticket_path(@ticket))
    else
      render action: "new"
    end
  end

  def show
    @ticket = Ticket.find(params[:id])
    check_permission(@ticket)
    respond_with(@ticket)
  end

  def update
    @ticket = Ticket.find(params[:id])
    if @ticket.claimant_id.present? && @ticket.claimant_id != CurrentUser.id && !params[:force_claim].to_s.truthy?
      flash[:notice] = "Ticket has already been claimed by somebody else, submit again to force"
      redirect_to ticket_path(@ticket, force_claim: "true")
      return
    end

    ticket_params = update_ticket_params
    @ticket.transaction do
      if @ticket.warnable? && ticket_params[:record_type].present?
        @ticket.content.user_warned!(ticket_params[:record_type].to_i, CurrentUser.user)
      end

      @ticket.handler_id = CurrentUser.id
      @ticket.claimant_id = CurrentUser.id
      @ticket.update(ticket_params)
    end

    if @ticket.valid?
      not_changed = ticket_params[:send_update_dmail].to_s.truthy? && (!@ticket.saved_change_to_response? && !@ticket.saved_change_to_status?)
      flash[:notice] = "Not sending update, no changes" if not_changed
      @ticket.push_pubsub("update")
    end

    respond_with(@ticket)
  end

  def claim
    @ticket = Ticket.find(params[:id])

    if @ticket.claimant.nil?
      @ticket.claim!
      return respond_with(@ticket)
    end
    flash[:notice] = "Ticket already claimed"
    respond_with(@ticket)
  end

  def unclaim
    @ticket = Ticket.find(params[:id])

    if @ticket.claimant.nil?
      flash[:notice] = "Ticket not claimed"
      return respond_with(@ticket)
    elsif @ticket.claimant.id != CurrentUser.id
      flash[:notice] = "Ticket not claimed by you"
      return respond_with(@ticket)
    elsif @ticket.approved?
      flash[:notice] = "Cannot unclaim approved ticket"
      return respond_with(@ticket)
    end
    @ticket.unclaim!
    flash[:notice] = "Claim removed"
    respond_with(@ticket)
  end

  private

  def ticket_params
    params.require(:ticket).permit(%i[qtype disp_id reason report_reason])
  end

  def update_ticket_params
    params.require(:ticket).permit(%i[response status record_type send_update_dmail])
  end

  def search_params
    current_search_params = params.fetch(:search, {})
    permitted_params = %i[qtype status order]
    permitted_params += %i[creator_id] if CurrentUser.is_moderator? || (current_search_params[:creator_id].present? && current_search_params[:creator_id].to_i == CurrentUser.id)
    permitted_params += %i[creator_name accused_name accused_id claimant_id claimant_name reason] if CurrentUser.is_moderator?
    permit_search_params permitted_params
  end

  def check_new_permission(ticket)
    raise(User::PrivilegeError) unless ticket.can_create_for?(CurrentUser.user)
  end

  def check_permission(ticket)
    raise(User::PrivilegeError) unless ticket.can_view?(CurrentUser.user)
  end
end
