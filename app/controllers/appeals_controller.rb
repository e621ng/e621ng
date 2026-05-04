# frozen_string_literal: true

class AppealsController < ApplicationController
  respond_to :html, :json, except: %i[create new]
  before_action :member_only, except: %i[index]

  def index
    @tickets = Ticket
               .where(qtype: "flag")
               .includes(:creator, :accused, :claimant)
               .visible(CurrentUser.user)
               .search(search_params)
               .paginate(params[:page], limit: params[:limit])
    preload_ticket_contents(@tickets)

    respond_with(@tickets) { |format| format.html { render "tickets/index" } }
  end

  def show
    @ticket = Ticket.find(params[:id])
    check_permission(@ticket)
    respond_with(@ticket) { |format| format.html { render "tickets/show" } }
  end

  private

  def search_params
    current_search_params = params.fetch(:search, {})
    permitted_params = %i[qtype status order]
    permitted_params += %i[creator_id] if CurrentUser.is_staff? || (current_search_params[:creator_id].present? && current_search_params[:creator_id].to_i == CurrentUser.id)
    permitted_params += %i[disp_id creator_name accused_name accused_id claimant_id claimant_name reason] if CurrentUser.is_staff?
    permit_search_params permitted_params
  end

  def preload_ticket_contents(tickets)
    tickets.group_by(&:qtype).each_value do |group|
      model = group.first.model
      next if model.nil?
      ids = group.map(&:disp_id).compact
      content_map = model.where(id: ids).index_by(&:id)
      group.each { |t| t.instance_variable_set(:@content, content_map[t.disp_id]) }
    end
  end

  def check_new_permission(ticket)
    raise(User::PrivilegeError) unless ticket.can_create_for?(CurrentUser.user)
  end

  def check_permission(ticket)
    raise(User::PrivilegeError) unless ticket.can_view?(CurrentUser.user)
  end
end
