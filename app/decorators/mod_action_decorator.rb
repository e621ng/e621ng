class ModActionDecorator < ApplicationDecorator
  def self.collection_decorator_class
    PaginatedDecorator
  end

  delegate_all

  def format_description
    vals = object.values
    return "" if vals.nil?

    if vals['user_id']
      user = "\"#{User.id_to_name(vals['user_id'])}\":/users/#{vals['user_id']}"
    elsif vals['username']
      user = "\"#{vals['username']}\":/users/?name=#{vals['username']}"
    end

    case object.action
      ### Pools ###
    when "pool_delete"
      "Deleted pool ##{vals['pool_id']} (named #{vals['pool_name']}) by #{user}"

      ### Takedowns ###
    when "takedown_process"
      "Completed takedown ##{vals['takedown_id']}"
    when "takedown_delete"
      "Deleted takedown ##{vals['takedown_id']}"

      ### IP Ban ###
    when "ip_ban_create"
      msg = "Created ip ban"
      if CurrentUser.is_admin?
        msg += " #{vals['ip_addr']}\nBan reason: #{vals['reason']}"
      end
      msg

    when "ip_ban_delete"
      msg = "Removed ip ban"
      if CurrentUser.is_admin?
        msg += " #{vals['ip_addr']}\nBan reason: #{vals['reason']}"
      end
      msg

      ### Ticket ###
    when "ticket_update"
      "Modified ticket ##{vals['ticket_id']}"
    when "ticket_claim"
      "Claimed ticket ##{vals['ticket_id']}"
    when "ticket_unclaim"
      "Unclaimed ticket ##{vals['ticket_id']}"

      ### Artist ###
    when "artist_page_rename"
      "Renamed artist page (\"#{vals['old_name']}\":/artists/show_or_new?name=#{vals['old_name']} -> \"#{vals['new_name']}\":/artists/show_or_new?name=#{vals['new_name']})"
    when "artist_page_lock"
      "Locked artist page artist ##{vals['artist_page']}"
    when "artist_page_unlock"
      "Unlocked artist page artist ##{vals['artist_page']}"
    when "artist_user_linked"
      "Linked #{user} to artist ##{vals['artist_page']}"
    when "artist_user_unlinked"
      "Unlinked #{user} from artist ##{vals['artist_page']}"

      ### User ###

    when "user_delete"
      "Deleted user #{user}"
    when "user_ban"
      if vals['duration'].is_a?(Numeric) && vals['duration'] < 0
        "Banned #{user} permanently"
      elsif vals['duration']
        "Banned #{user} for #{vals['duration']} #{vals['duration'] == 1 ? 'day' : 'days'}"
      else
        "Banned #{user}"
      end
    when "user_unban"
      "Unbanned #{user}"

    when "user_level_change"
      "Changed #{user} level from #{vals['level_was']} to #{vals['level']}"
    when "user_flags_change"
      "Changed #{user} flags. Added: [#{vals['added'].join(', ')}] Removed: [#{vals['removed'].join(', ')}]"
    when "edited_user"
      "Edited #{user}"
    when "user_blacklist_changed"
      "Edited blacklist of #{user}"
    when "changed_user_text", "user_text_change"
      "Changed profile text of #{user}"
    when "user_upload_limit_change"
      "Changed upload limit of #{user} from #{vals['old_upload_limit']} to #{vals['new_upload_limit']}"
    when "user_name_change"
      "Changed name of #{user} from #{vals['old_name']} to #{vals['new_name']}"

      ### User Record ###

    when "user_feedback_create"
      "Created #{vals['type'].capitalize} record ##{vals['record_id']} for #{user} with reason: #{vals['reason']}"
    when "user_feedback_update"
      if vals["reason_was"].present? || vals["type_was"].present?
        text = "Edited record ##{vals['record_id']} for #{user}"
        if vals["type"] != vals["type_was"]
          text += "\nChanged type from #{vals['type_was']} to #{vals['type']}"
        end
        if vals["reason"] != vals["reason_was"]
          text += "\nChanged reason: [section=Old]#{vals['reason_was']}[/section] [section=New]#{vals['reason']}[/section]"
        end
        text
      else
        "Edited #{vals['type']} record ##{vals['record_id']} for #{user} to: #{vals['reason']}"
      end
    when "user_feedback_delete"
      "Deleted #{vals['type']} record ##{vals['record_id']} for #{user} with reason: #{vals['reason']}"
      ### Legacy User Record ###
    when "created_positive_record"
      "Created positive record ##{vals['record_id']} for #{user} with reason: #{vals['reason']}"
    when "created_neutral_record"
      "Created neutral record ##{vals['record_id']} for #{user} with reason: #{vals['reason']}"
    when "created_negative_record"
      "Created negative record ##{vals['record_id']} for #{user} with reason: #{vals['reason']}"

      ### Set ###

    when "set_change_visibility"
      "Made set ##{vals['set_id']} by #{user} #{vals['is_public'] ? 'public' : 'private'}"
    when "set_update"
      "Edited set ##{vals['set_id']} by #{user}"
    when "set_delete"
      "Deleted set ##{vals['set_id']} by #{user}"

      ### Comment ###

    when "comment_update"
      "Edited comment ##{vals['comment_id']} by #{user}"
    when "comment_delete"
      "Deleted comment ##{vals['comment_id']} by #{user}"
    when "comment_hide"
      "Hid comment ##{vals['comment_id']} by #{user}"
    when "comment_unhide"
      "Unhid comment ##{vals['comment_id']} by #{user}"

      ### Forum Post ###

    when "forum_post_delete"
      "Deleted forum ##{vals['forum_post_id']} in topic ##{vals['forum_topic_id']} by #{user}"
    when "forum_post_update"
      "Edited forum ##{vals['forum_post_id']} in topic ##{vals['forum_topic_id']} by #{user}"
    when "forum_post_hide"
      "Hid forum ##{vals['forum_post_id']} in topic ##{vals['forum_topic_id']} by #{user}"
    when "forum_post_unhide"
      "Unhid forum ##{vals['forum_post_id']} in topic ##{vals['forum_topic_id']} by #{user}"
    when "forum_topic_hide"
      "Hid topic ##{vals['forum_topic_id']} (with title #{vals['forum_topic_title']}) by #{user}"
    when "forum_topic_unhide"
      "Unhid topic ##{vals['forum_topic_id']} (with title #{vals['forum_topic_title']}) by #{user}"
    when "forum_topic_delete"
      "Deleted topic ##{vals['forum_topic_id']} (with title #{vals['forum_topic_title']}) by #{user}"
    when "forum_topic_stick"
      "Stickied topic ##{vals['forum_topic_id']} (with title #{vals['forum_topic_title']}) by #{user}"
    when "forum_topic_unstick"
      "Unstickied topic ##{vals['forum_topic_id']} (with title #{vals['forum_topic_title']}) by #{user}"
    when "forum_topic_lock"
      "Locked topic ##{vals['forum_topic_id']} (with title #{vals['forum_topic_title']}) by #{user}"
    when "forum_topic_unlock"
      "Unlocked topic ##{vals['forum_topic_id']} (with title #{vals['forum_topic_title']}) by #{user}"

      ### Forum Category ###

    when "forum_category_create"
      "Created forum category ##{vals['forum_category_id']}"
    when "forum_category_update"
      "Edited forum category ##{vals['forum_category_id']}"
    when "forum_category_delete"
      "Deleted forum category ##{vals['forum_category_id']}"

      ### Blip ###

    when "blip_update"
      "Edited blip ##{vals['blip_id']} by #{user}"
    when "blip_delete"
      if vals['username']
        "Deleted blip ##{vals['blip_id']} by #{user}"
      else
        "Deleted blip ##{vals['blip_id']}"
      end
    when "blip_hide"
      if vals['username']
        "Hid blip ##{vals['blip_id']} by #{user}"
      else
        "Hid blip ##{vals['blip_id']}"
      end
    when "blip_unhide"
      "Unhid blip ##{vals['blip_id']} by #{user}"

      ### Alias ###

    when "tag_alias_create"
      if vals[:tag1]
        "Created tag alias ({{#{vals[:tag1]}}} → {{#{vals[:tag2]}}})"
      else
        "Created tag alias #{vals['alias_desc']}"
      end
    when "tag_alias_approve"
      if vals[:tag1]
        "Approved tag alias ({{#{vals[:tag1]}}} → {{#{vals[:tag2]}}})"
      end
    when "tag_alias_delete"
      if vals[:tag1]
        "Deleted tag alias ({{#{vals[:tag1]}}} → {{#{vals[:tag2]}}})"
      end
    when "tag_alias_update"
      if vals[:tag1]
        "Edited tag alias ({{#{vals[:oldtag1]}}} → {{#{vals[:oldtag2]}}}) to ({{#{vals[:tag1]}}} → {{#{vals[:tag2]}}})"
      else
        "Updated tag alias #{vals['alias_desc']}\n#{vals['change_desc']}"
      end

      ### Implication ###

    when "tag_implication_create"
      if vals[:tag1]
        "Created tag implication ({{#{vals[:tag1]}}} → {{#{vals[:tag2]}}})"
      else
        "Created tag implication #{vals['implication_desc']}"
      end
    when "tag_implication_approve"
      if vals[:tag1]
        "Approved tag implication ({{#{vals[:tag1]}}} → {{#{vals[:tag2]}}})"
      end
    when "tag_implicaton_delete"
      if vals[:tag1]
        "Deleted tag implication ({{#{vals[:tag1]}}} → {{#{vals[:tag2]}}})"
      end
    when "tag_implication_update"
      if vals[:tag1]
        "Edited tag implication ({{#{vals[:oldtag1]}}} → {{#{vals[:oldtag2]}}}) to ({{#{vals[:tag1]}}} → {{#{vals[:tag2]}}})"
      else
        "Updated tag implication #{vals['implication_desc']}\n#{vals['change_desc']}"
      end

      ### BURs ###

    when "mass_update"
      "Mass updated [[#{vals['antecedent']}]] -> [[#{vals['consequent']}]]"
    when "nuke_tag"
      "Nuked tag [[#{vals['tag_name']}]]"

      ### Flag Reason ###

    when "created_flag_reason"
      "Created flag reason ##{vals['flag_reason_id']} (#{vals['flag_reason']})"
    when "edited_flag_reason"
      "Edited flag reason ##{vals['flag_reason_id']} (#{vals['flag_reason']})"
    when "deleted_flag_reason"
      "Deleted flag reason ##{vals['flag_reason_id']} (#{vals['flag_reason']})"

      ### Post Report Reasons ###

    when "report_reason_create"
      "Created post report reason #{vals['reason']}"
    when "report_reason_update"
      text = "Edited post report reason #{vals['reason']}"
      if vals["reason"] != vals["reason_was"]
        text += "\nChanged reason from \"#{vals['reason_was']}\" to \"#{vals['reason']}\""
      end
      if vals["description"] != vals["description_was"]
        text += "\nChanged description from \"#{vals['description_was']}\" to \"#{vals['description']}\""
      end
      text
    when "report_reason_delete"
      "Deleted post report reason #{vals['reason']} by #{user}"

      ### Whitelist ###

    when "upload_whitelist_create"
      if vals['hidden'] && !CurrentUser.is_admin?
        "Created whitelist entry"
      else
        "Created whitelist entry '#{CurrentUser.is_admin? ? vals['pattern'] : vals['note']}'"
      end

    when "upload_whitelist_update"
      if vals['hidden'] && !CurrentUser.is_admin?
        "Edited whitelist entry"
      else
        if vals['old_pattern'] && vals['old_pattern'] != vals['pattern'] && CurrentUser.is_admin?
          "Edited whitelist entry '#{vals['old_pattern']}' -> '#{vals['pattern']}'"
        else
          "Edited whitelist entry '#{CurrentUser.is_admin? ? vals['pattern'] : vals['note']}'"
        end
      end

    when "upload_whitelist_delete"
      if vals['hidden'] && !CurrentUser.is_admin?
        "Deleted whitelist entry"
      else
        "Deleted whitelist entry '#{CurrentUser.is_admin? ? vals['pattern'] : vals['note']}'"
      end

      ### Help ###

    when "help_create"
      "Created help entry \"#{vals['name']}\":/help/#{HelpPage.normalize_name(vals['name'])} ([[#{vals['wiki_page']}]])"
    when "help_update"
      "Edited help entry \"#{vals['name']}\":/help/#{HelpPage.normalize_name(vals['name'])} ([[#{vals['wiki_page']}]])"
    when "help_delete"
      "Deleted help entry \"#{vals['name']}\":/help/#{HelpPage.normalize_name(vals['name'])} ([[#{vals['wiki_page']}]])"

      ### Wiki ###
    when "wiki_page_delete"
      "Deleted wiki page [[#{vals['wiki_page']}]]"
    when "wiki_page_lock"
      "Locked wiki page [[#{vals['wiki_page']}]]"
    when "wiki_page_unlock"
      "Unlocked wiki page [[#{vals['wiki_page']}]]"
    when "wiki_page_rename"
      "Renamed wiki page ([[#{vals['old_title']}]] → [[#{vals['new_title']}]])"

      ### Mascots ###
    when "mascot_create"
      "Created mascot ##{vals['id']}"
    when "mascot_update"
      "Updated mascot ##{vals['id']}"
    when "mascot_delete"
      "Deleted mascot ##{vals['id']}"

    when "bulk_revert"
      "Processed bulk revert for #{vals['constraints']} by #{user}"

      ### Legacy Post Events ###
    when "post_move_favorites"
      "Moves favorites from post ##{vals['post_id']} to post ##{vals['parent_id']}"
    when "post_delete"
      "Deleted post ##{vals['post_id']} with reason: #{vals['reason']}"
    when "post_undelete"
      "Undeleted post ##{vals['post_id']}"
    when "post_destroy"
      "Destroyed post ##{vals['post_id']}"
    when "post_rating_lock"
      "Post rating was #{vals['locked'] ? 'locked' : 'unlocked'} on post ##{vals['post_id']}"
    when "post_unapprove"
      "Unapproved post ##{vals['post_id']}"

    when "post_replacement_accept"
      "Post replacement for post ##{vals['post_id']} was accepted"
    when "post_replacement_reject"
      "Post replacement for post ##{vals['post_id']} was rejected"
    when "post_replacement_delete"
      "Post replacement for post ##{vals['post_id']} was deleted"

    else
      CurrentUser.is_admin? ? "Unknown action #{object.action}: #{object.values.inspect}" : "Unknown action #{object.action}"
    end
  end
end
