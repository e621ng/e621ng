# frozen_string_literal: true

class AvoidPostingsController < ApplicationController
  respond_to :html, :json
  before_action :can_edit_avoid_posting_entries_only, except: %i[index show]
  before_action :load_avoid_posting, only: %i[edit update destroy show delete undelete]
  helper_method :search_params

  def index
    @avoid_postings = AvoidPosting.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@avoid_postings)
  end

  def show
    respond_with(@avoid_posting)
  end

  def new
    @avoid_posting = AvoidPosting.new(avoid_posting_params)
    @avoid_posting.artist = Artist.new(avoid_posting_params[:artist_attributes])
    respond_with(@artist)
  end

  def edit
  end

  def create
    @avoid_posting = AvoidPosting.create(avoid_posting_params(:create))
    respond_with(@avoid_posting)
  end

  def update
    @avoid_posting.update(avoid_posting_params)
    flash[:notice] = @avoid_posting.valid? ? "Avoid posting entry updated" : @avoid_posting.errors.full_messages.join("; ")
    respond_with(@avoid_posting)
  end

  def destroy
    @avoid_posting.destroy
    redirect_to artist_path(@avoid_posting.artist), notice: "Avoid posting entry destroyed"
  end

  def delete
    @avoid_posting.update(is_active: false)
    redirect_to avoid_posting_path(@avoid_posting), notice: "Avoid posting entry deleted"
  end

  def undelete
    @avoid_posting.update(is_active: true)
    redirect_to avoid_posting_path(@avoid_posting), notice: "Avoid posting entry undeleted"
  end

  private

  def load_avoid_posting
    id = params[:id]
    if id =~ /\A\d+\z/
      @avoid_posting = AvoidPosting.find(id)
    else
      @avoid_posting = AvoidPosting.find_by!(artist_name: id)
    end
  end

  def search_params
    permitted_params = %i[creator_name creator_id any_name_matches artist_id artist_name any_other_name_matches group_name details is_active]
    permitted_params += %i[staff_notes] if CurrentUser.is_staff?
    permitted_params += %i[creator_ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end

  def avoid_posting_params
    permitted_params = %i[details staff_notes is_active]
    permitted_params += [artist_attributes: %i[id name other_names other_names_string group_name linked_user_id]]

    params.fetch(:avoid_posting, {}).permit(permitted_params)
  end
end
