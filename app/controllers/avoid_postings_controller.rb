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
    @avoid_posting = AvoidPosting.new(avoid_posting_params)
    artparams = avoid_posting_params.try(:[], :artist_attributes)
    if artparams.present? && (artist = Artist.named(artparams[:name]))
      @avoid_posting.artist = artist
      notices = []
      if artist.other_names.present? && (artparams.key?(:other_names_string) || artparams.key?(:other_names))
        on = artparams[:other_names_string].try(:split) || artparams[:other_names]
        artparams.delete(:other_names_string)
        artparams.delete(:other_names)
        if on.present?
          artparams[:other_names] = (artist.other_names + on).uniq
          notices << "Artist already had other names, the provided names were merged into the existing names."
        end
      end
      if artist.group_name.present? && artparams.key?(:group_name)
        if artparams[:group_name].blank?
          artparams.delete(:group_name)
        else
          notices << "Artist's original group name was replaced."
        end
      end
      if artist.linked_user_id.present? && artparams.key?(:linked_user_id)
        if artparams[:linked_user_id].present?
          notices << "Artist is already linked to \"#{artist.linked_user.name}\":/users/#{artist.linked_user_id}, no change was made."
        end
        artparams.delete(:linked_user_id)
      end
      notices = notices.join("\n")
      # Remove period from last notice
      flash[:notice] = notices[0..-2] if notices.present?
      artist.update(artparams)
    end
    @avoid_posting.save
    respond_with(@avoid_posting)
  end

  def update
    @avoid_posting.update(avoid_posting_params)
    flash[:notice] = @avoid_posting.valid? ? "Avoid posting entry updated" : @avoid_posting.errors.full_messages.join("; ")
    respond_with(@avoid_posting)
  end

  def destroy
    @avoid_posting.destroy
    redirect_to(artist_path(@avoid_posting.artist), notice: "Avoid posting entry destroyed")
  end

  def delete
    @avoid_posting.update(is_active: false)
    redirect_back(fallback_location: avoid_posting_path(@avoid_posting), notice: "Avoid posting entry deleted")
  end

  def undelete
    @avoid_posting.update(is_active: true)
    redirect_back(fallback_location: avoid_posting_path(@avoid_posting), notice: "Avoid posting entry undeleted")
  end

  private

  def load_avoid_posting
    id = params[:id]
    if id =~ /\A\d+\z/
      @avoid_posting = AvoidPosting.find(id)
    else
      @avoid_posting = AvoidPosting.joins(:artist).find_by!("artists.name": id)
    end
  end

  def search_params
    permitted_params = %i[creator_name creator_id any_name_matches artist_id artist_name any_other_name_matches group_name details is_active order]
    permitted_params += %i[staff_notes] if CurrentUser.is_staff?
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end

  def avoid_posting_params
    permitted_params = %i[details staff_notes is_active]
    permitted_params += [artist_attributes: [:id, :name, :other_names_string, :group_name, :linked_user_id, { other_names: [] }]]

    params.fetch(:avoid_posting, {}).permit(permitted_params)
  end
end
