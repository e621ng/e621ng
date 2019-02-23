class TakedownsController < ApplicationController
  respond_to :html, :xml, :json
  before_action :admin_only, only: [:update, :destroy, :add_by_ids, :add_by_tags, :count_matching_posts, :remove_by_id]

  def index
    @takedowns = Takedown.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@takedowns)
  end

  def destroy
    @takedown = Takedown.find(params[:id])
    @takedown.destroy
  end

  def show
    @takedown = Takedown.find(params[:id])
    @show_instructions = (CurrentUser.ip_addr == @takedown.creator_ip_addr) || (@takedown.vericode == params[:code])
    respond_with(@takedown, @show_instructions)
  end

  def new
    @takedown = Takedown.new
    respond_with(@takedown)
  end

  def create
    @takedown = Takedown.create(takedown_params)
    flash[:notice] = @takedown.valid? ? "Takedown created" : @takedown.errors.full_messages.join(". ")
    if @takedown.valid?
      redirect_to(takedown_url(@takedown, code: @takedown.vericode))
    else
      respond_with(@takedown)
    end
  end

  def update
    takedown = Takedown.find(params[:id])

    takedown.notes = params[:takedown][:notes]
    takedown.reason_hidden = params[:takedown][:reason_hidden]
    takedown.approver = current_user.id

    # If the takedown is pending or inactive, and the new status is pending or inactive
    if ["pending", "inactive"].include?(takedown.status) && ["pending", "inactive"].include?(params[:takedown][:status])
      takedown.status = params[:takedown][:status]
    end

    if params[:process_takedown]
      # Handle posts, delete ones marked for deletion
      if params[:takedown_posts]
        params[:takedown_posts].each do |post_id, value|

          takedown_post = TakedownPost.find_by_takedown_id_and_post_id(takedown.id, post_id)

          takedown_post.status = status = (value == "1" ? "deleted" : "kept")
          takedown_post.save

          if takedown_post.status == "deleted"
            takedown_post.post.undelete!(current_user) if takedown_post.post.is_deleted?
            delete_reason = params[:delete_reason].presence || "Artist requested removal"
            Resque.enqueue(
                DeletePost,
                post_id,
                "takedown ##{takedown.id}: #{delete_reason}",
                current_user.id,
                false) #Do not transfer favorites on takedowns.
          end
          if takedown_post.post.status == "deleted" && takedown_post.status == "kept"
            takedown_post.post.undelete!(current_user)
          end
        end
      end

      # Calculate and update the status (approved, partial, denied) based on number of kept/deleted posts
      takedown.status = takedown.calculated_status

      ModAction.create(user_id: current_user.id, action: "completed_takedown", values: {takedown_id: takedown.id})
    end

    if takedown.save
      respond_to_success("Request updated, status set to #{takedown.status}", {action: "show", id: takedown.id})

      if params[:takedown][:process_takedown] && takedown.email.include?("@")
        begin
          UserMailer::deliver_takedown_updated(takedown, current_user)
        rescue Net::SMTPAuthenticationError, Net::SMTPServerBusy, Net::SMTPSyntaxError, Net::SMTPFatalError, Net::SMTPUnknownError => e
          flash[:error] = 'Error emailing: ' + e.message
        end
      end
    else
      respond_to_error(takedown, action: "show", id: takedown.id)
    end
  end

  def add_by_ids
    begin
      takedown = Takedown.find(params[:id])
    rescue ActiveRecord::RecordNotFound => x
      respond_to_error("Takedown ##{params[:id]} not found", action: "index")
      return
    end

    added_post_ids = takedown.add_post_ids(params[:post_ids])
    api_return = {added_count: added_post_ids.length, added_post_ids: added_post_ids}

    respond_to do |fmt|
      fmt.html {respond_to_success("#{added_post_ids.length} posts added to takedown ##{params[:id]}", action: "show", id: params[:id])}
      fmt.xml {render xml: api_return.to_xml}
      fmt.json {render json: api_return.to_json, callback: params[:callback]}
    end
  end

  def add_by_tags
    begin
      takedown = Takedown.find(params[:id])
    rescue ActiveRecord::RecordNotFound => x
      respond_to_error("Takedown ##{params[:id]} not found", action: "index")
      return
    end

    posts = Post.find_by_sql(Post.generate_sql(
        QueryParser.parse(params[:tags].to_s + " status:any order:id_asc").join(" "),
        user: current_user,
        select: "posts.id"
    ))

    # Collect all post ids into an array
    post_ids = posts.map(&:id)

    added_post_ids = takedown.add_post_ids(post_ids)
    api_return = {added_count: added_post_ids.length, added_post_ids: added_post_ids}

    respond_to do |fmt|
      fmt.html {respond_to_success("#{added_count} posts with tags '#{}' added to takedown ##{params[:id]}", action: "show", id: params[:id])}
      fmt.xml {render xml: api_return.to_xml}
      fmt.json {render json: api_return.to_json, callback: params[:callback]}
    end
  end

  def count_matching_posts
    posts = Post.find_by_sql(Post.generate_sql(
        QueryParser.parse(params[:tags].to_s + " status:any").join(" "),
        user: current_user,
        select: "posts.id"
    ))

    api_return = {matched_post_count: posts.length}

    respond_to do |fmt|
      fmt.xml {render xml: api_return.to_xml}
      fmt.json {render json: api_return.to_json, callback: params[:callback]}
    end
  end

  def remove_by_id
    begin
      takedown_post = TakedownPost.find_by_takedown_id_and_post_id(params[:id], params[:post_id])
    rescue ActiveRecord::RecordNotFound => x
      respond_to_error("Post ##{params[:post_id]} not found in takedown ##{params[:id]}", action: "show", id: params[:id])
      return
    end

    takedown_post.destroy
    respond_to_success("Post ##{params[:post_id]} removed from takedown ##{params[:id]}", action: "show", id: params[:id])
  end

  private

  def search_params
    permitted_params = %i[status]
    if CurrentUser.is_admin?
      permitted_params << %i[source reason ip_addr creator_id creator_name email vericode status order]
    end
    params.fetch(:search, {}).permit(*permitted_params)
  end

  def takedown_params
    permitted_params = %i[email source instructions reason post_ids reason_hidden]
    if CurrentUser.is_admin?
      permitted_params << %i[notes del_post_ids status]
    end
    params.require(:takedown).permit(*permitted_params, post_ids: [])
  end
end
