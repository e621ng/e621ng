class PostsController < ApplicationController
  before_action :member_only, :except => [:show, :show_seq, :index, :home, :random]
  before_action :admin_only, only: [:update_iqdb]
  respond_to :html, :json

  def index
    if params[:md5].present?
      @post = Post.find_by!(md5: params[:md5])
      respond_with(@post) do |format|
        format.html { redirect_to(@post) }
      end
    else
      @post_set = PostSets::Post.new(tag_query, params[:page], params[:limit], random: params[:random])
      @posts = PostsDecorator.decorate_collection(@post_set.posts)
      respond_with(@posts) do |format|
        format.json do
          render json: @post_set.api_posts, root: 'posts'
        end
        format.atom
      end
    end
  end

  def show
    @post = Post.find(params[:id])

    include_deleted = @post.is_deleted? || (@post.parent_id.present? && @post.parent.is_deleted?) || CurrentUser.is_approver?
    @parent_post_set = PostSets::PostRelationship.new(@post.parent_id, :include_deleted => include_deleted, want_parent: true)
    @children_post_set = PostSets::PostRelationship.new(@post.id, :include_deleted => include_deleted, want_parent: false)
    @comment_votes = {}
    @comment_votes = CommentVote.for_comments_and_user(@post.comments.visible(CurrentUser.user).map(&:id), CurrentUser.id) if request.format.html?

    respond_with(@post)
  end

  def show_seq
    context = PostSearchContext.new(params)
    pid = context.post_id ? context.post_id : params[:id]

    @post = Post.find(pid)
    include_deleted = @post.is_deleted? || (@post.parent_id.present? && @post.parent.is_deleted?) || CurrentUser.is_approver?
    @parent_post_set = PostSets::PostRelationship.new(@post.parent_id, :include_deleted => include_deleted, want_parent: true)
    @children_post_set = PostSets::PostRelationship.new(@post.id, :include_deleted => include_deleted, want_parent: false)
    @comment_votes = {}
    @comment_votes = CommentVote.for_comments_and_user(@post.comments.visible(CurrentUser.user).map(&:id), CurrentUser.id) if request.format.html?
    @fixup_post_url = true

    respond_with(@post) do |fmt|
      fmt.html { render 'posts/show'}
    end
  end

  def update
    @post = Post.find(params[:id])
    ensure_can_edit(@post)

    pparams = post_params
    pparams.delete(:tag_string) if pparams[:tag_string_diff].present?
    pparams.delete(:source) if pparams[:source_diff].present?
    @post.update(pparams)
    respond_with_post_after_update(@post)
  end

  def revert
    @post = Post.find(params[:id])
    ensure_can_edit(@post)
    @version = @post.versions.find(params[:version_id])

    @post.revert_to!(@version)

    respond_with(@post) do |format|
      format.js
    end
  end

  def copy_notes
    @post = Post.find(params[:id])
    ensure_can_edit(@post)
    @other_post = Post.find(params[:other_post_id].to_i)
    @post.copy_notes_to(@other_post)

    if @post.errors.any?
      @error_message = @post.errors.full_messages.join("; ")
      render :json => {:success => false, :reason => @error_message}.to_json, :status => 400
    else
      head :no_content
    end
  end

  def random
    tags = params[:tags] || ''
    @post = Post.tag_match(tags + " order:random").limit(1).first
    raise ActiveRecord::RecordNotFound if @post.nil?
    respond_with(@post) do |format|
      format.html { redirect_to post_path(@post, :tags => params[:tags]) }
    end
  end

  def mark_as_translated
    @post = Post.find(params[:id])
    ensure_can_edit(@post)
    @post.mark_as_translated(params[:post])
    respond_with_post_after_update(@post)
  end

  def update_iqdb
    @post = Post.find(params[:id])
    @post.update_iqdb_async
    respond_with_post_after_update(@post)
  end

  private

  def tag_query
    params[:tags] || (params[:post] && params[:post][:tags])
  end

  def respond_with_post_after_update(post)
    respond_with(post) do |format|
      format.html do
        if post.warnings.any?
          warnings = post.warnings.full_messages.join(".\n \n")
          if warnings.length > 45_000
            Dmail.create_automated({
                                       to_id: CurrentUser.id,
                                       title: "Post update notices for post ##{post.id}",
                                       body: "While editing post ##{post.id} some notices were generated. Please review them below:\n\n#{warnings[0..45_000]}"
                                   })
            flash[:notice] = "What the heck did you even do to this poor post? That generated way too many warnings. But you get a dmail with most of them anyways"
          elsif warnings.length > 1500
            Dmail.create_automated({
                                       to_id: CurrentUser.id,
                                       title: "Post update notices for post ##{post.id}",
                                       body: "While editing post ##{post.id} some notices were generated. Please review them below:\n\n#{warnings}"
                                   })
            flash[:notice] = "This edit created a LOT of notices. They have been dmailed to you. Please review them"
          else
            flash[:notice] = warnings
          end
        end

        if post.errors.any?
          @message = post.errors.full_messages.join("; ")
          render :template => "static/error", :status => 500
        else
          response_params = {:q => params[:tags_query], :pool_id => params[:pool_id], post_set_id: params[:post_set_id]}
          response_params.reject!{|key, value| value.blank?}
          redirect_to post_path(post, response_params)
        end
      end

      format.json do
        render :json => post
      end
    end
  end

  def ensure_can_edit(post)
    can_edit = CurrentUser.can_post_edit_with_reason
    raise User::PrivilegeError.new("Updater #{User.throttle_reason(can_edit)}") unless can_edit == true
  end

  def post_params
    permitted_params = %i[
      tag_string old_tag_string
      tag_string_diff source_diff
      parent_id old_parent_id
      source old_source
      description old_description
      rating old_rating
      edit_reason
    ]
    permitted_params += %i[is_rating_locked] if CurrentUser.is_privileged?
    permitted_params += %i[is_note_locked bg_color] if CurrentUser.is_janitor?
    permitted_params += %i[is_status_locked is_comment_locked locked_tags hide_from_anonymous hide_from_search_engines] if CurrentUser.is_admin?

    params.require(:post).permit(permitted_params)
  end

  def allowed_readonly_actions
    super + %w[random show_seq]
  end
end
