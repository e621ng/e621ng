# frozen_string_literal: true

require "rails_helper"

# ---------------------------------------------------------------------------
# TagRelationship shared behavior — exercised through TagImplication
# ---------------------------------------------------------------------------

RSpec.describe TagImplication do
  it_behaves_like "tag_relationship factory",          :tag_implication, TagImplication
  it_behaves_like "tag_relationship validations",      :tag_implication, TagImplication
  it_behaves_like "tag_relationship normalizations",   :tag_implication, TagImplication
  it_behaves_like "tag_relationship scopes",           :tag_implication, TagImplication
  it_behaves_like "tag_relationship instance methods", :tag_implication, TagImplication
  it_behaves_like "tag_relationship search",           :tag_implication, TagImplication
  it_behaves_like "tag_relationship message methods",  :tag_implication, TagImplication
end
