module PostSetMaintainerHelper
  def invite_links(m)
    html = ""
    if m.status == "pending"
      html << link_to("Accept", approve_post_set_maintainer_path(m), data: {confirm: "Are you sure you want to accept this invite?"})
      html << " " + link_to("Ignore", deny_post_set_maintainer_path(m), data: {confirm: "Are you sure you want to ignore this invite?"})
      html << " " + link_to("Block", block_post_set_maintainer_path(m), data: {confirm: "Are you sure you want to ignore and block future invites for this set?"})
    elsif m.status == "approved"
      html << link_to("Remove", deny_post_set_maintainer_path(m), data: {confirm: "Are you sure you want to remove yourself as maintainer of this set?"})
      html << " " + link_to("Block", block_post_set_maintainer_path(m), data: {confirm: "Are you sure you want to remove yourself and block future invites for this set?"})
    elsif m.status == "blocked"
      html << link_to("Unblock", deny_post_set_maintainer_path(m), data: {confirm: "Are you sure you want to unblock invites for this set?"})
    end
    html.html_safe
  end
end
