class TagAliasRequest < TagRelationshipRequest
  def self.topic_title(antecedent_name, consequent_name)
    "Tag alias: #{antecedent_name} -> #{consequent_name}"
  end

  def tag_relationship_class
    TagAlias
  end
end
