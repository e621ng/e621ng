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
      "Deleted pool ##{vals['pool_id']}(named #{vals['pool_name']}) by #{user}"
    when "pool_undelete"
      "Undeleted pool ##{vals['pool_id']}(named #{vals['pool_name']}) by #{user}"

      ### Takedowns ###
    when "takedown_process"
      "Completed takedown ##{vals['takedown_id']}"

      ### IP Ban ###
    when "ip_ban_create"
      "Created ip ban"
    when "ip_ban_deleted"
      "Removed ip ban"

      ### Ticket ###
    when "ticket_update"
      "Modified ticket ##{vals['ticket_id']}"
    when "ticket_claim"
      "Claimed ticket ##{vals['ticket_id']}"
    when "ticket_unclaim"
      "Unclaimed ticket ##{vals['ticket_id']}"

      ### Artist ###
    when "artist_ban"
      "Marked artist ##{vals['artist_id']} as DNP"
    when "artist_unban"
      "Marked artist ##{vals['artist_id']} as no longer DNP"

      ### User ###

    when "user_delete"
      "Deleted user #{user}"
    when "user_ban"
      if vals['duration'] == "permanent"
        "Permanently banned #{user}"
      elsif vals['duration']
        "Banned #{user} for #{vals['duration']} #{vals['duration'] == 1 ? "day" : "days"}"
      else
        "Banned #{user}"
      end
    when "user_unban"
      "Unbanned #{user}"

    when "user_level_change"
      "Changed #{user} level from #{vals['level_was']} to #{vals['level']}"
    when "user_flags_change"
      "Changed #{user} flags. Added: #{vals['added'].join(', ')}. Removed: #{vals['removed'].join(', ')}"
    when "edited_user"
      "Edited #{user}"
    when "changed_user_blacklist"
      "Edited blacklist of #{user}"
    when "changed_user_text"
      "Changed profile text of #{user}"
    when "user_name_change"
      "Changed named of #{user} from #{vals['old_name']} to #{vals['new_naame']}"

      ### User Record ###

    when "user_feedback_create"
      "Created #{vals['type'].capitalize} record ##{vals['record_id']} for #{user} with reason: #{vals['reason']}"
    when "user_feedback_update"
      "Edited #{vals['type']} record ##{vals['record_id']} for #{user} to: #{vals['reason']}"
    when "user_feedback_delete"
      "Deleted #{vals['type']} record ##{vals['record_id']} for #{user} with reason: #{vals['reason']}"
      ### Legacy User Record ###
    when "created_positive_record"
      "Created positive record ##{vals['record_id']} for #{user} with reason: #{vals['reason']}"
    when "created_neutral_record"
      "Created neutral record ##{vals['record_id']} for #{user} with reason: #{vals['reason']}"
    when "created_negative_record"
      "Created negative record ##{vals['record_id']} for #{user} with reason: #{vals['reason']}"

      ### Post ###

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

      ### Set ###

    when "set_mark_private"
      "Made set ##{vals['set_id']} by #{user} private"
    when "set_update"
      "Edited set ##{vals['set_id']} by #{user}"
    when "set_delete"
      "Deleted set ##{vals['set_id']} by #{user}"

      ### Comment ###

    when "comment_update"
      "Edited comment ##{vals['comment_id']} by #{user}"
    when "comment_delete"
      if vals['username']
        "Deleted comment ##{vals['comment_id']} by #{user}"
      else
        "Deleted comment ##{vals['comment_id']}"
      end
      # TODO: Not currently implemented
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
      "Unstickied forum ##{vals['forum_topic_id']} (with title #{vals['forum_topic_title']}) by #{user}"
    when "forum_topic_lock"
      "Locked topic ##{vals['forum_topic_id']} (with title #{vals['forum_topic_title']}) by #{user}"
    when "forum_topic_unlock"
      "Unlocked topic ##{vals['forum_topic_id']} (with title #{vals['forum_topic_title']}) by #{user}"

      ### Forum Category ###

    when "created_forum_category"
      "Created forum category ##{vals['forum_category_id']}"
    when "edited_forum_category"
      "Edited forum category ##{vals['forum_category_id']}"
    when "deleted_forum_category"
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
        "Created tag alias ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
      else
        "Created tag alias #{vals['alias_desc']}"
      end
    when "tag_alias_approve"
      if vals[:tag1]
        "Approved tag alias ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
      else
      end
    when "tag_alias_delete"
      if vals[:tag1]
        "Deleted tag alias ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
      else
      end
    when "tag_alias_update"
      if vals[:tag1]
        "Edited tag alias ({{#{vals[:oldtag1]}}} &rarr; {{#{vals[:oldtag2]}}}) to ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
      else
        "Updated tag alias #{vals['alias_desc']}\n#{vals['change_desc']}"
      end

      ### Implication ###

    when "tag_implication_create"
      if vals[:tag1]
        "Created tag implication ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
      else
        "Created tag implicaiton #{vals['implication_desc']}"
      end
    when "tag_implication_approve"
      if vals[:tag1]
        "Approved tag implication ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
      else
      end
    when "tag_implicaton_delete"
      if vals[:tag1]
        "Deleted tag implication ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
      else
      end
    when "tag_implication_update"
      if vals[:tag1]
        "Edited tag implication ({{#{vals[:oldtag1]}}} &rarr; {{#{vals[:oldtag2]}}}) to ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
      else
        "Updated tag implication #{vals['implication_desc']}\n#{vals['change_desc']}"
      end

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
      "Edited post report reason #{vals['reason_was']} to #{vals['reason']}"
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
          "Edited whitelist entry '#{vals['pattern']}' -> '#{vals['old_pattern']}'"
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
      "Created help entry \"#{vals['name']}\":/help/show/#{vals['name']} ([[#{vals['wiki_page']}]])"
    when "help_update"
      "Edited help entry \"#{vals['name']}\":/help/show/#{vals['name']} ([[#{vals['wiki_page']}]])"
    when "help_delete"
      "Deleted help entry \"#{vals['name']}\":/help/show/#{vals['name']} ([[#{vals['wiki_page']}]])"

      ### Wiki ###
    when "wiki_page_delete"
      "Deleted wiki page [[#{vals['wiki_page']}]]"
    when "wiki_page_undelete"
      "Undeleted wiki page [[#{vals['wiki_page']}"
    when "wiki_page_lock"
      "Locked wiki page [[#{vals['wiki_page']}]]"
    when "wiki_page_unlock"
      "Unlocked wiki page [[#{vals['wiki_page']}]]"
    when "wiki_page_rename"
      "Renamed wiki page ([[#{vals['old_title']}]] → [[#{vals['new_title']}]])"

    when "bulk_revert"
      "Processed bulk revert for #{vals['constraints']} by #{user}"


    else
      CurrentUser.is_admin? ? "Unknown action #{object.action}: #{object.values.inspect}" : "Unknown action #{object.action}"
    end
  end
end
