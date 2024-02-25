# frozen_string_literal: true

module ForumTopicsHelper
  def forum_topic_category_select(object, field, options = {})
    select(object, field, ForumCategory.visible.reverse_mapping, options)
  end

  def tag_request_message(obj)
    if obj.is_a?(TagRelationship)
      if obj.is_approved?
        return "The #{obj.relationship} ##{obj.id} [[#{obj.antecedent_name}]] -> [[#{obj.consequent_name}]] has been approved."
      elsif obj.is_retired?
        return "The #{obj.relationship} ##{obj.id} [[#{obj.antecedent_name}]] -> [[#{obj.consequent_name}]] has been retired."
      elsif obj.is_deleted?
        return "The #{obj.relationship} ##{obj.id} [[#{obj.antecedent_name}]] -> [[#{obj.consequent_name}]] has been rejected."
      elsif obj.is_pending?
        return "The #{obj.relationship} ##{obj.id} [[#{obj.antecedent_name}]] -> [[#{obj.consequent_name}]] is pending approval."
      elsif obj.is_errored?
        return "The #{obj.relationship} ##{obj.id} [[#{obj.antecedent_name}]] -> [[#{obj.consequent_name}]] (#{obj.relationship} failed during processing."
      else # should never happen
        return "The #{obj.relationship} ##{obj.id} [[#{obj.antecedent_name}]] -> [[#{obj.consequent_name}]] has an unknown status."
      end
    end

    if obj.is_a?(BulkUpdateRequest)
      if obj.script.size < 700
        embedded_script = script_with_line_breaks(obj, with_decorations: false)
      else
        embedded_script = "[section]#{script_with_line_breaks(obj, with_decorations: false)}[/section]"
      end

      if obj.is_approved?
        return "The #{obj.bulk_update_request_link} is active.\n\n#{embedded_script}"
      elsif obj.is_pending?
        return "The #{obj.bulk_update_request_link} is pending approval.\n\n#{embedded_script}"
      elsif obj.is_rejected?
        return "The #{obj.bulk_update_request_link} has been rejected.\n\n#{embedded_script}"
      end
    end
  end

  def parse_embedded_tag_request_text(text)
    [TagAlias, TagImplication, BulkUpdateRequest].each do |tag_request|
      text = text.gsub(tag_request.embedded_pattern) do |match|
        begin
          obj = tag_request.find($~[:id])
          tag_request_message(obj) || match

        rescue ActiveRecord::RecordNotFound
          match
        end
      end
    end

    text
  end
end
