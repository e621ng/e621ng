# frozen_string_literal: true

class TagAliasRequest < TagRelationshipRequest
  def self.topic_title(antecedent_name, consequent_name)
    "Tag alias: #{antecedent_name} -> #{consequent_name}"
  end

  def self.command_string(antecedent_name, consequent_name, id = nil)
    if id
      return "[ta:#{id}]"
    end

    "create alias [[#{antecedent_name}]] -> [[#{consequent_name}]]"
  end

  def tag_relationship_class
    TagAlias
  end
end
