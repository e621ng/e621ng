class DmailsController < ApplicationController
  respond_to :html
  respond_to :json, only: %i[index show destroy mark_as_read mark_all_as_read]
  before_action :member_only

  def new
    if params[:respond_to_id]
      parent = Dmail.find(params[:respond_to_id])
      check_privilege(parent)
      @dmail = parent.build_response(:forward => params[:forward])
    else
      @dmail = Dmail.new(create_params)
    end

    respond_with(@dmail)
  end

  def index
    if params[:folder] && params[:set_default_folder]
      cookies.permanent[:dmail_folder] = params[:folder]
    end
    @query = Dmail.active.visible.search(search_params)
    @dmails = @query.paginate(params[:page], :limit => params[:limit])
    respond_with(@dmails)
  end

  def show
    @dmail = Dmail.find(params[:id])
    check_privilege(@dmail)
    respond_with(@dmail) do |fmt|
      fmt.html { @dmail.mark_as_read! unless Danbooru.config.readonly_mode? }
    end
  end

  def create
    @dmail = Dmail.create_split(create_params)
    respond_with(@dmail)
  end

  def destroy
    @dmail = Dmail.find(params[:id])
    check_privilege(@dmail)
    @dmail.mark_as_read!
    @dmail.update_column(:is_deleted, true)
    respond_to do |format|
      format.html { redirect_to dmails_path, notice: "Message destroyed" }
      format.json
    end
  end

  def mark_as_read
    @dmail = Dmail.find(params[:id])
    check_privilege(@dmail)
    @dmail.mark_as_read!
  end

  def mark_all_as_read
    Dmail.visible.unread.each do |x|
      x.update_column(:is_read, true)
    end
    CurrentUser.user.update(has_mail: false, unread_dmail_count: 0)
    respond_to do |format|
      format.html { redirect_to dmails_path, notice: "All messages marked as read" }
      format.json
    end
  end

  private

  def check_privilege(dmail)
    if !dmail.visible_to?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def create_params
    params.fetch(:dmail, {}).permit(:title, :body, :to_name, :to_id)
  end
end
