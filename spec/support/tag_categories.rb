# frozen_string_literal: true

# Category IDs are hardcoded to avoid coupling to locale-specific names:
#   general=0  artist=1  contributor=2  copyright=3  character=4
#   species=5  invalid=6  meta=7  lore=8
RSpec.shared_context "with tag categories" do
  let(:general_tag_category) { 0 }
  let(:artist_tag_category) { 1 }
  # NOTE: contributor category is unavailable on e6ai, and thus is not used in tests
  let(:copyright_tag_category) { 3 }
  let(:character_tag_category) { 4 }
  let(:species_tag_category) { 5 }
  let(:invalid_tag_category) { 6 }
  let(:meta_tag_category) { 7 }
  let(:lore_tag_category) { 8 }
end
