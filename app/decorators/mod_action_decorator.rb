class ModActionDecorator < ApplicationDecorator
  def self.collection_decorator_class
    PaginatedDecorator
  end

  delegate_all

  def format_description
    vals = object.values

    if vals[:user_id]
      user = "\"#{User.id_to_pretty_name(vals[:user_id])}\":/users/#{vals[:user_id]}"
    elsif vals[:username]
      user = "\"#{vals[:username]}\":/users/?name=#{vals[:username]}"
    end

    case object.action
    when "deleted_pool"
      "Deleted pool ##{vals[:pool_id]}"
    when "completed_takedown"
      "Completed takedown ##{vals[:takedown_id]}"
    when "modified_ticket"
      "Modified ticket ##{vals[:ticket_id]}"
    when "claim_ticket"
      "Claimed ticket ##{vals[:ticket_id]}"
    when "unclaim_ticket"
      "Unclaimed ticket ##{vals[:ticket_id]}"

      ### User ###
    when "user_ban"
      if vals[:duration] == "permanent"
        "Permanently banned #{user}"
      elsif vals[:duration]
        "Banned #{user} for #{vals[:duration]} #{vals[:duration] == 1 ? "day" : "days"}"
      else
        "Banned #{user}"
      end
    when "user_unban"
      "Unbanned #{user}"

    when "edited_user"
      "Edited #{user}"
    when "changed_user_blacklist"
      "Edited blacklist of #{user}"
    when "changed_user_level"
      "Changed #{user} to #{vals[:level]}"
    when "changed_user_text"
      "Changed profile text of #{user}"

      ### User Record ###

    when "created_positive_record"
      "Created positive record ##{vals[:record_id]} for #{user} with reason: #{vals[:reason]}"
    when "created_neutral_record"
      "Created neutral record ##{vals[:record_id]} for #{user} with reason: #{vals[:reason]}"
    when "created_negative_record"
      "Created negative record ##{vals[:record_id]} for #{user} with reason: #{vals[:reason]}"
    when "edited_record"
      "Edited #{vals[:type]} record ##{vals[:record_id]} for #{user} to: #{vals[:reason]}"
    when "deleted_record"
      "Deleted #{vals[:type]} record ##{vals[:record_id]} for #{user} with reason: #{vals[:reason]}"

      ### Post ###

    when "deleted_post"
      "Deleted post ##{vals[:post_id]}"
    when "undeleted_post"
      "Undeleted post ##{vals[:post_id]}"
    when "destroyed_post"
      "Destroyed post ##{vals[:post_id]}"
    when "rating_locked"
      "Post rating was #{vals[:locked] ? 'locked' : 'unlocked'} on post ##{vals[:post_id]}"

      ### Set ###

    when "made_set_private"
      "Made set ##{vals[:set_id]} by #{user} private"
    when "edited_set"
      "Edited set ##{vals[:set_id]} by #{user}"

      ### Comment ###

    when "edited_comment"
      "Edited comment ##{vals[:comment_id]} by #{user}"
    when "deleted_comment"
      if vals[:username]
        "Deleted comment ##{vals[:comment_id]} by #{user}"
      else
        "Deleted comment ##{vals[:comment_id]}"
      end
    when "hid_comment"
      "Hid comment ##{vals[:comment_id]} by #{user}"
    when "unhid_comment"
      "Unhid comment ##{vals[:comment_id]} by #{user}"

      ### Forum Post ###

    when "deleted_forum_post"
      "Deleted forum ##{vals[:forum_post_id]} by #{user}"
    when "edited_forum_post"
      "Edited forum ##{vals[:forum_post_id]} by #{user}"
    when "hid_forum_post"
      "Hid forum ##{vals[:forum_post_id]} by #{user}"
    when "unhid_forum_post"
      "Unhid forum ##{vals[:forum_post_id]} by #{user}"
    when "stickied_forum_post"
      "Stickied forum ##{vals[:forum_post_id]} by #{user}"
    when "unstickied_forum_post"
      "Unstickied forum ##{vals[:forum_post_id]} by #{user}"
    when "locked_forum_post"
      "Locked forum ##{vals[:forum_post_id]} by #{user}"
    when "unlocked_forum_post"
      "Unlocked forum ##{vals[:forum_post_id]} by #{user}"

      ### Forum Category ###

    when "created_forum_category"
      "Created forum category ##{vals[:forum_category_id]}"
    when "edited_forum_category"
      "Edited forum category ##{vals[:forum_category_id]}"
    when "deleted_forum_category"
      "Deleted forum category ##{vals[:forum_category_id]}"

      ### Blip ###

    when "edited_blip"
      "Edited blip ##{vals[:blip_id]} by #{user}"
    when "deleted_blip"
      if vals[:username]
        "Deleted blip ##{vals[:blip_id]} by #{user}"
      else
        "Deleted blip ##{vals[:blip_id]}"
      end
    when "hid_blip"
      if vals[:username]
        "Hid blip ##{vals[:blip_id]} by #{user}"
      else
        "Hid blip ##{vals[:blip_id]}"
      end
    when "unhid_blip"
      "Unhid blip ##{vals[:blip_id]} by #{user}"

      ### Alias ###

    when "created_alias"
      "Created tag alias ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
    when "approved_alias"
      "Approved tag alias ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
    when "deleted_alias"
      "Deleted tag alias ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
    when "edited_alias"
      "Edited tag alias ({{#{vals[:oldtag1]}}} &rarr; {{#{vals[:oldtag2]}}}) to ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"

      ### Implication ###

    when "created_implication"
      "Created tag implication ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
    when "approved_implication"
      "Approved tag implication ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
    when "deleted_implication"
      "Deleted tag implication ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"
    when "edited_implication"
      "Edited tag implication ({{#{vals[:oldtag1]}}} &rarr; {{#{vals[:oldtag2]}}}) to ({{#{vals[:tag1]}}} &rarr; {{#{vals[:tag2]}}})"

      ### Flag Reason ###

    when "created_flag_reason"
      "Created flag reason ##{vals[:flag_reason_id]} (#{vals[:flag_reason]})"
    when "edited_flag_reason"
      "Edited flag reason ##{vals[:flag_reason_id]} (#{vals[:flag_reason]})"
    when "deleted_flag_reason"
      "Deleted flag reason ##{vals[:flag_reason_id]} (#{vals[:flag_reason]})"

      ### Whitelist ###

    when "created_upload_whitelist"
      if vals[:hidden] && options[:userlevel] < 50
        "Created whitelist entry"
      else
        "Created whitelist entry '#{options[:userlevel] == 50 ? vals[:pattern] : vals[:note]}'"
      end

    when "edited_upload_whitelist"
      if vals[:hidden] && options[:userlevel] < 50
        "Edited whitelist entry"
      else
        if vals[:old_pattern] && vals[:old_pattern] != vals[:pattern] && options[:userlevel] == 50
          "Edited whitelist entry '#{vals[:pattern]}' -> '#{vals[:old_pattern]}'"
        else
          "Edited whitelist entry '#{options[:userlevel] == 50 ? vals[:pattern] : vals[:note]}'"
        end
      end

    when "deleted_upload_whitelist"
      if vals[:hidden] && options[:userlevel] < 50
        "Deleted whitelist entry"
      else
        "Deleted whitelist entry '#{options[:userlevel] == 50 ? vals[:pattern] : vals[:note]}'"
      end

      ### Help ###

    when "created_help_entry"
      "Created help entry \"#{vals[:name]}\":/help/show/#{vals[:name]} ([[#{vals[:wiki_page]}]])"
    when "edited_help_entry"
      "Edited help entry \"#{vals[:name]}\":/help/show/#{vals[:name]} ([[#{vals[:wiki_page]}]])"
    when "deleted_help_entry"
      "Deleted help entry \"#{vals[:name]}\":/help/show/#{vals[:name]} ([[#{vals[:wiki_page]}]])"

      ### Wiki ###

    when "deleted_wiki_page"
      "Deleted wiki page [[#{vals[:wiki_page]}]]"
    when "locked_wiki_page"
      "Locked wiki page [[#{vals[:wiki_page]}]]"
    when "unlocked_wiki_page"
      "Unlocked wiki page [[#{vals[:wiki_page]}]]"
    when "renamed_wiki_page"
      "Renamed wiki page ([[#{vals[:old_title]}]] → [[#{vals[:new_title]}]])"
    else
      "Unknown action #{object.action}: #{object.values.inspect}"
    end
  end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

end
