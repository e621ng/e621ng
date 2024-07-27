# frozen_string_literal: true

module Admin
  class StaffNotesController < ApplicationController
    before_action :can_view_staff_notes_only
    respond_to :html

    def index
      @user = User.find_by(id: params[:user_id])
      @notes = StaffNote.search(search_params.merge({ user_id: params[:user_id] })).includes(:user, :creator).paginate(params[:page], limit: params[:limit])
      respond_with(@notes)
    end

    def new
      @user = User.find(params[:user_id])
      @staff_note = StaffNote.new(note_params)
      respond_with(@note)
    end

    def create
      @user = User.find(params[:user_id])
      @staff_note = StaffNote.create(note_params.merge({creator: CurrentUser.user, user_id: @user.id}))
      flash[:notice] = @staff_note.valid? ? "Staff Note added" : @staff_note.errors.full_messages.join("; ")
      respond_with(@staff_note) do |format|
        format.html do
          redirect_back fallback_location: admin_staff_notes_path
        end
      end
    end

    private

    def search_params
      permit_search_params(%i[creator_id creator_name user_id user_name resolved body_matches without_system_user])
    end

    def note_params
      params.fetch(:staff_note, {}).permit(%i[body])
    end
  end
end
