class TagImplicationRequest < TagRelationshipRequest
  def self.topic_title(antecedent_name, consequent_name)
    "Tag implication: #{antecedent_name} -> #{consequent_name}"
  end

  def tag_relationship_class
    TagImplication
  end
end
