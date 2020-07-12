class DtextPreviewsController < ApplicationController
  def create
    @body = params[:body] || ""
    @post_ids = Set.new
    @html = ""
    begin
      parsed = DTextRagel.parse(@body, disable_mentions: true, allow_color: CurrentUser.user.is_privileged?)
      raise DTextRagel::Error.new if parsed.nil?
      @post_ids.merge(parsed[1]) if parsed[1].present?
      @html = parsed[0].html_safe
    rescue DTextRagel::Error => e
    end
    render json: {html: @html, posts: deferred_posts(@post_ids)}
  end

  private

  def deferred_posts(ids)
    Post.includes(:uploader).where(id: ids.to_a).find_each.reduce({}) do |post_hash, p|
      post_hash[p.id] = p.minimal_attributes
      post_hash
    end
  end
end
