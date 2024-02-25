# frozen_string_literal: true

class TagImplicationRequest < TagRelationshipRequest
  def self.topic_title(antecedent_name, consequent_name)
    "Tag implication: #{antecedent_name} -> #{consequent_name}"
  end

  def self.command_string(antecedent_name, consequent_name, id = nil)
    if id
      return "[ti:#{id}]"
    end

    "create implication [[#{antecedent_name}]] -> [[#{consequent_name}]]"
  end

  def tag_relationship_class
    TagImplication
  end
end
