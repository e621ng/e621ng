# frozen_string_literal: true

class PostsController < ApplicationController
  before_action :member_only, except: %i[show show_seq index random]
  before_action :admin_only, only: [:update_iqdb]
  before_action :ensure_lockdown_disabled, except: %i[index show show_seq random report]
  respond_to :html, :json

  def index
    if params[:md5].present?
      @post = Post.find_by!(md5: params[:md5])
      respond_with(@post) do |format|
        format.html { redirect_to(@post) }
      end
    else
      @post_set = PostSets::Post.new(tag_query, params[:page], limit: params[:limit], random: params[:random])
      @posts = PostsDecorator.decorate_collection(@post_set.posts)

      @query = tag_query.nil? ? [] : tag_query.strip.split(/ /, 2).compact_blank
      if @query.length == 1
        @wiki_page = WikiPage.titled(@query[0])

        # redirect?
        if @wiki_page.present? && @wiki_page.parent.present?
          @wiki_page = WikiPage.titled(@wiki_page.parent)
        end

        @wiki_text = @wiki_page.present? ? @wiki_page.body : ""
        if @wiki_text.present?
          @wiki_text = @wiki_text
                       .gsub(/thumb #\d+ ?/, "")
                       .strip
                       .truncate(512)
        end
      end

      respond_with(@posts) do |format|
        format.json do
          render json: @post_set.api_posts, root: "posts"
        end
        format.atom
      end
    end
  end

  def show
    @post = Post.includes(:uploader, :approver).find(params[:id])

    raise User::PrivilegeError, "Post unavailable" unless Security::Lockdown.post_visible?(@post, CurrentUser.user)

    include_deleted = @post.is_deleted? || (@post.parent_id.present? && @post.parent.is_deleted?) || CurrentUser.is_approver?
    @parent_post_set = PostSets::PostRelationship.new(@post.parent_id, include_deleted: include_deleted, want_parent: true)
    @children_post_set = PostSets::PostRelationship.new(@post.id, include_deleted: include_deleted, want_parent: false)

    @has_samples = @post.is_image? || @post.video_sample_list[:has]

    if request.format.html? && @post.comment_count > 0
      @comments = @post.comments.includes(:creator, :updater).visible(CurrentUser.user)
      @comment_votes = CommentVote.for_comments_and_user(@comments.map(&:id), CurrentUser.id)
    else
      @comments = Comment.none
      @comment_votes = CommentVote.none
    end

    respond_with(@post)
  end

  def show_seq
    @post = PostSearchContext.new(params).post

    raise User::PrivilegeError, "Post unavailable" unless Security::Lockdown.post_visible?(@post, CurrentUser.user)

    include_deleted = @post.is_deleted? || (@post.parent_id.present? && @post.parent.is_deleted?) || CurrentUser.is_approver?
    @parent_post_set = PostSets::PostRelationship.new(@post.parent_id, include_deleted: include_deleted, want_parent: true)
    @children_post_set = PostSets::PostRelationship.new(@post.id, include_deleted: include_deleted, want_parent: false)

    if request.format.html? && @post.comment_count > 0
      @comments = @post.comments.includes(:creator, :updater).visible(CurrentUser.user)
      @comment_votes = CommentVote.for_comments_and_user(@comments.map(&:id), CurrentUser.id)
    else
      @comments = Comment.none
      @comment_votes = CommentVote.none
    end

    @fixup_post_url = true

    respond_with(@post) do |format|
      format.html { render "posts/show" }
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

    respond_with(@post, &:js)
  end

  def copy_notes
    @post = Post.find(params[:id])
    ensure_can_edit(@post)
    @other_post = Post.find(params[:other_post_id].to_i)
    @post.copy_notes_to(@other_post)

    if @post.errors.any?
      @error_message = @post.errors.full_messages.join("; ")
      render json: { success: false, reason: @error_message }.to_json, status: 400
    else
      head 204
    end
  end

  def random
    tags = params[:tags] || ""
    @post = Post.tag_match("#{tags} order:random").limit(1).first
    raise ActiveRecord::RecordNotFound if @post.nil?
    respond_with(@post) do |format|
      format.html { redirect_to post_path(@post, q: params[:tags]) }
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

  # Unified report/flag action for posts
  # Handles both POST flags (rule violations) and reports (other issues)
  # Uses the PostFlagReason model to determine available reasons
  # GET: Shows the report form with flag and report reason options
  # POST: Creates either a PostFlag or Ticket based on the report type
  def report
    @post = Post.find(params[:id])
    
    if request.get?
      # Show the report form
      @flag_reasons = PostFlagReason.for_flags.ordered
      @report_reasons = PostFlagReason.for_reports.ordered
      
      # Check if we have any reasons configured
      if @flag_reasons.empty? && @report_reasons.empty?
        flash[:notice] = "No flag or report reasons are currently configured"
        redirect_to @post and return
      end
      
      respond_with(@post) do |format|
        format.html { render :report }
      end
    elsif request.post?
      # Handle report submission
      report_type = params[:report_type]
      reason_name = params[:reason]
      explanation = params[:explanation]

      # Basic validation
      if report_type.blank? || reason_name.blank?
        flash[:notice] = "Please select a report type and reason"
        redirect_to report_post_path(@post) and return
      end

      # Validate that the reason exists and matches the report type
      if report_type == 'flag'
        reason = PostFlagReason.for_flags.find_by(name: reason_name)
      elsif report_type == 'report'
        reason = PostFlagReason.for_reports.find_by(name: reason_name)
      else
        flash[:notice] = "Invalid report type"
        redirect_to report_post_path(@post) and return
      end

      unless reason
        flash[:notice] = "Invalid reason selected"
        redirect_to report_post_path(@post) and return
      end

      # Check if explanation is required
      if reason.require_explanation && explanation.blank?
        flash[:notice] = "Explanation is required for this reason"
        redirect_to report_post_path(@post) and return
      end

      # Create the flag or report based on type
      if report_type == 'flag'
        @post_flag = PostFlag.create(
          post: @post,
          creator: CurrentUser.user,
          reason: reason.reason,
          explanation: explanation
        )
        
        if @post_flag.errors.empty?
          flash[:notice] = "Post flagged successfully"
          redirect_to @post
        else
          flash[:notice] = @post_flag.errors.full_messages.join("; ")
          redirect_to report_post_path(@post)
        end
      else
        # Create a ticket for reports using PostFlagReason
        # Note: This assumes the ticket system is updated to work with PostFlagReason
        # For now, we'll create a simple report record or ticket
        @ticket = Ticket.create(
          creator: CurrentUser.user,
          qtype: "post",
          disp_id: @post.id,
          reason: explanation.present? ? "#{reason.reason}: #{explanation}" : reason.reason
        )
        
        if @ticket.errors.empty?
          flash[:notice] = "Report submitted successfully"
          redirect_to @post
        else
          flash[:notice] = @ticket.errors.full_messages.join("; ")
          redirect_to report_post_path(@post)
        end
      end
    end
  rescue ActiveRecord::RecordNotFound
    flash[:notice] = "Post not found"
    redirect_to posts_path
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
              body: "While editing post ##{post.id} some notices were generated. Please review them below:\n\n#{warnings[0..45_000]}",
            })
            flash[:notice] = "What the heck did you even do to this poor post? That generated way too many warnings. But you get a dmail with most of them anyways"
          elsif warnings.length > 1500
            Dmail.create_automated({
              to_id: CurrentUser.id,
              title: "Post update notices for post ##{post.id}",
              body: "While editing post ##{post.id} some notices were generated. Please review them below:\n\n#{warnings}",
            })
            flash[:notice] = "This edit created a LOT of notices. They have been dmailed to you. Please review them"
          else
            flash[:notice] = warnings
          end
        end

        if post.errors.any?
          @message = post.errors.full_messages.join("; ")
          if flash[:notice].present?
            flash[:notice] += "\n\n#{@message}"
          else
            flash[:notice] = @message
          end
        end
        response_params = { q: params[:tags_query], pool_id: params[:pool_id], post_set_id: params[:post_set_id] }
        response_params.compact_blank!
        redirect_to post_path(post, response_params)
      end

      format.json do
        render json: post
      end
    end
  end

  def ensure_can_edit(_post)
    can_edit = CurrentUser.can_post_edit_with_reason
    raise User::PrivilegeError, "Updater #{User.throttle_reason(can_edit)}" unless can_edit == true
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.uploads_disabled? && !CurrentUser.is_staff?
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
    permitted_params += %i[is_comment_locked] if CurrentUser.is_moderator?
    permitted_params += %i[is_status_locked is_comment_disabled locked_tags hide_from_anonymous hide_from_search_engines] if CurrentUser.is_admin?

    params.require(:post).permit(permitted_params)
  end
end
