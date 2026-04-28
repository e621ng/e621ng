# frozen_string_literal: true

require "rails_helper"

# ---------------------------------------------------------------------------
# TagRelationship shared behavior — exercised through TagAlias
# ---------------------------------------------------------------------------
# TagImplication will include the same shared examples when its spec is added.

RSpec.describe TagAlias do
  it_behaves_like "tag_relationship factory",          :tag_alias, TagAlias
  it_behaves_like "tag_relationship validations",      :tag_alias, TagAlias
  it_behaves_like "tag_relationship normalizations",   :tag_alias, TagAlias
  it_behaves_like "tag_relationship scopes",           :tag_alias, TagAlias
  it_behaves_like "tag_relationship instance methods", :tag_alias, TagAlias
  it_behaves_like "tag_relationship search",           :tag_alias, TagAlias
  it_behaves_like "tag_relationship message methods",  :tag_alias, TagAlias
end
