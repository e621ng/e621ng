# frozen_string_literal: true

module Staff
  class StaffFilesController < ApplicationController
    respond_to :html, :json
    before_action :staff_only
    before_action :load_staff_file, only: %i[show destroy]
    before_action :check_delete_permission, only: %i[destroy]

    def index
      @staff_files = StaffFile
                     .includes(:creator)
                     .search(search_params)
                     .paginate(params[:page], limit: params[:limit], search_count: params[:search])
      respond_with(@staff_files)
    end

    def show
      respond_with(@staff_file)
    end

    def new
      @staff_file = StaffFile.new
      respond_with(@staff_file)
    end

    def create
      @staff_file = StaffFileUploader.create!(staff_file_params)
      if @staff_file.valid?
        ModAction.log(:staff_file_create, { id: @staff_file.id, filename: @staff_file.original_filename, file_size: @staff_file.file_size, user_id: @staff_file.creator_id })
      end
      respond_with(@staff_file, location: staff_files_path)
    end

    def destroy
      if @staff_file.destroy
        Danbooru.config.storage_manager.delete_staff_file(@staff_file)
        ModAction.log(:staff_file_delete, { id: @staff_file.id, filename: @staff_file.original_filename, user_id: @staff_file.creator_id })
      end
      respond_with(@staff_file, location: staff_files_path)
    end

    private

    def load_staff_file
      @staff_file = StaffFile.find(params[:id])
    end

    def check_delete_permission
      raise User::PrivilegeError unless @staff_file.can_delete?(CurrentUser.user)
    end

    def staff_file_params
      params.fetch(:staff_file, {}).permit(%i[file title description])
    end

    def search_params
      permit_search_params %i[creator_id creator_name original_filename file_ext order]
    end
  end
end
