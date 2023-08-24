module Admin
  class StuckDnpController < ApplicationController
    before_action :admin_only

    def new
    end

    def create
      query = create_params[:query]

      if query.blank?
        flash[:notice] = "No query specified"
        redirect_to new_admin_stuck_dnp_path
        return
      end

      dnp_tags = %w[avoid_posting conditional_dnp]
      post_ids = []
      CurrentUser.without_safe_mode do
        Post.tag_match("#{query} ~avoid_posting ~conditional_dnp").limit(1000).records.each do |p|
          contains_avoid_posting = p.has_tag?("avoid_posting")
          contains_conditional_dnp = p.has_tag?("conditional_dnp")

          p.do_not_version_changes = true

          locked_tags = TagQuery.scan((p.locked_tags || "").downcase)
          locked_tags -= dnp_tags
          p.locked_tags = locked_tags.join(" ")
          p.remove_tag(dnp_tags)

          p.save

          if contains_avoid_posting != p.has_tag?("avoid_posting") || contains_conditional_dnp != p.has_tag?("conditional_dnp")
            post_ids << p.id
          end
        end
      end

      StaffAuditLog.log(:stuck_dnp, CurrentUser.user, { query: query, post_ids: post_ids })
      flash[:notice] = "DNP tags removed from #{post_ids.count} posts"
      redirect_to new_admin_stuck_dnp_path
    end

    private

    def create_params
      params.require(:stuck_dnp).permit(%i[query])
    end
  end
end
