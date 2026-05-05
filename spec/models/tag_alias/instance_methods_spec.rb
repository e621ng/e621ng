# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAlias do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # #dtext_label
  # ---------------------------------------------------------------------------

  describe "#dtext_label" do
    it "returns [ta:id] for a persisted alias" do
      ta = create(:tag_alias)
      expect(ta.dtext_label).to eq("[ta:#{ta.id}]")
    end
  end

  # ---------------------------------------------------------------------------
  # #ensure_category_consistency
  # ---------------------------------------------------------------------------

  describe "#ensure_category_consistency" do
    subject(:ta) do
      create(:tag_alias,
             antecedent_name: "ant_#{SecureRandom.hex(4)}",
             consequent_name: "con_#{SecureRandom.hex(4)}")
    end

    it "does not change category when consequent post_count exceeds 10_000" do
      ta.consequent_tag.update_columns(post_count: 10_001, category: Tag.categories.general)
      ta.antecedent_tag.update_columns(category: 1)
      expect { ta.ensure_category_consistency }.not_to(change { ta.consequent_tag.reload.category })
    end

    it "does not change category when consequent tag is locked" do
      ta.consequent_tag.update_columns(is_locked: true, category: Tag.categories.general)
      ta.antecedent_tag.update_columns(category: 1)
      expect { ta.ensure_category_consistency }.not_to(change { ta.consequent_tag.reload.category })
    end

    it "does not change category when consequent tag is already non-general" do
      ta.consequent_tag.update_columns(category: 1)
      ta.antecedent_tag.update_columns(category: 3)
      expect { ta.ensure_category_consistency }.not_to(change { ta.consequent_tag.reload.category })
    end

    it "does not change category when antecedent tag is general" do
      ta.antecedent_tag.update_columns(category: Tag.categories.general)
      ta.consequent_tag.update_columns(category: Tag.categories.general)
      expect { ta.ensure_category_consistency }.not_to(change { ta.consequent_tag.reload.category })
    end

    it "updates consequent tag category to antecedent category in the happy path" do
      ta.antecedent_tag.update_columns(category: 1)
      ta.consequent_tag.update_columns(category: Tag.categories.general)
      ta.ensure_category_consistency
      expect(ta.consequent_tag.reload.category).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # #create_undo_information
  # ---------------------------------------------------------------------------

  describe "#create_undo_information" do
    it "creates a TagRelUndo record" do
      ta = create(:tag_alias)
      expect { ta.create_undo_information }.to change(TagRelUndo, :count).by(1)
    end

    it "records the IDs of posts that have the antecedent tag" do
      ta = create(:tag_alias,
                  antecedent_name: "undo_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "undo_con_#{SecureRandom.hex(4)}")
      post = create(:post)
      post.update_column(:tag_string, "#{ta.antecedent_name} other_tag")

      ta.create_undo_information

      expect(ta.tag_rel_undos.first.undo_data).to include(post.id)
    end
  end

  # ---------------------------------------------------------------------------
  # #update_blacklists
  # ---------------------------------------------------------------------------

  describe "#update_blacklists" do
    it "replaces the antecedent tag with the consequent tag in user blacklists" do
      ta = create(:tag_alias,
                  antecedent_name: "bl_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "bl_con_#{SecureRandom.hex(4)}")
      ta.update_columns(status: "processing")

      user = create(:user)
      user.update_column(:blacklisted_tags, ta.antecedent_name)

      ta.update_blacklists

      expect(user.reload.blacklisted_tags).to include(ta.consequent_name)
      expect(user.reload.blacklisted_tags).not_to include(ta.antecedent_name)
    end
  end

  # ---------------------------------------------------------------------------
  # #update_posts_locked_tags
  # ---------------------------------------------------------------------------

  describe "#update_posts_locked_tags" do
    it "replaces the antecedent tag with the consequent tag in post locked_tags" do
      ta = create(:tag_alias,
                  antecedent_name: "lock_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "lock_con_#{SecureRandom.hex(4)}")
      ta.update_columns(status: "processing")

      post = create(:post)
      post.update_column(:locked_tags, ta.antecedent_name)

      ta.update_posts_locked_tags

      expect(post.reload.locked_tags).to include(ta.consequent_name)
      expect(post.reload.locked_tags).not_to include(ta.antecedent_name)
    end
  end

  # ---------------------------------------------------------------------------
  # #update_posts_locked_tags_undo
  # ---------------------------------------------------------------------------

  describe "#update_posts_locked_tags_undo" do
    it "replaces the consequent tag with the antecedent tag in post locked_tags" do
      ta = create(:active_tag_alias,
                  antecedent_name: "lock_undo_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "lock_undo_con_#{SecureRandom.hex(4)}")

      post = create(:post)
      post.update_column(:locked_tags, ta.consequent_name)

      ta.update_posts_locked_tags_undo

      expect(post.reload.locked_tags).to include(ta.antecedent_name)
      expect(post.reload.locked_tags).not_to include(ta.consequent_name)
    end
  end

  # ---------------------------------------------------------------------------
  # #update_blacklists_undo
  # ---------------------------------------------------------------------------

  describe "#update_blacklists_undo" do
    it "replaces the consequent tag with the antecedent tag in user blacklists" do
      ta = create(:active_tag_alias,
                  antecedent_name: "bl_undo_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "bl_undo_con_#{SecureRandom.hex(4)}")

      user = create(:user)
      user.update_column(:blacklisted_tags, ta.consequent_name)

      ta.update_blacklists_undo

      expect(user.reload.blacklisted_tags).to include(ta.antecedent_name)
      expect(user.reload.blacklisted_tags).not_to include(ta.consequent_name)
    end
  end

  # ---------------------------------------------------------------------------
  # #update_posts_undo
  # ---------------------------------------------------------------------------

  describe "#update_posts_undo" do
    it "applies tag diffs from unapplied TagRelUndo records to matching posts" do
      ta = create(:active_tag_alias,
                  antecedent_name: "undo_post_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "undo_post_con_#{SecureRandom.hex(4)}")
      # Set to pending so normalize_tags doesn't re-alias the antecedent back to the
      # consequent during the post save (mirrors what process_undo! does before calling this).
      ta.update_columns(status: "pending")

      post = create(:post)
      post.update_column(:tag_string, "#{ta.consequent_name} other_tag")
      ta.tag_rel_undos.create!(undo_data: [post.id])

      ta.update_posts_undo

      expect(post.reload.tag_string).to include(ta.antecedent_name)
    end

    it "calls fix_post_count for antecedent and consequent tags" do
      ta = create(:active_tag_alias)
      ta.tag_rel_undos.create!(undo_data: [])

      allow(ta.antecedent_tag).to receive(:fix_post_count)
      allow(ta.consequent_tag).to receive(:fix_post_count)

      ta.update_posts_undo

      expect(ta.antecedent_tag).to have_received(:fix_post_count)
      expect(ta.consequent_tag).to have_received(:fix_post_count)
    end
  end

  # ---------------------------------------------------------------------------
  # #rename_artist
  # ---------------------------------------------------------------------------

  describe "#rename_artist" do
    it "does nothing when the antecedent tag is not in the artist category" do
      ta = create(:tag_alias,
                  antecedent_name: "gen_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "gen_con_#{SecureRandom.hex(4)}")
      ta.antecedent_tag.update_columns(category: Tag.categories.general)

      expect { ta.rename_artist }.not_to(change(Artist, :count))
    end

    it "renames the antecedent artist to the consequent name when the consequent has no artist" do
      ta = create(:tag_alias,
                  antecedent_name: "art_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "art_con_#{SecureRandom.hex(4)}")
      ta.antecedent_tag.update_columns(category: 1)
      create(:artist, name: ta.antecedent_name)

      ta.rename_artist

      expect(Artist.find_by(name: ta.consequent_name)).to be_present
    end

    it "transfers linked_user_id from antecedent artist to consequent artist when both exist" do
      ta = create(:tag_alias,
                  antecedent_name: "art_ant2_#{SecureRandom.hex(4)}",
                  consequent_name: "art_con2_#{SecureRandom.hex(4)}")
      ta.antecedent_tag.update_columns(category: 1)
      linked_user = create(:user)
      create(:artist, name: ta.antecedent_name, linked_user_id: linked_user.id)
      con_artist = create(:artist, name: ta.consequent_name)

      ta.rename_artist

      expect(con_artist.reload.linked_user_id).to eq(linked_user.id)
      expect(ta.antecedent_tag.artist.reload.linked_user_id).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # #rename_artist_undo
  # ---------------------------------------------------------------------------

  describe "#rename_artist_undo" do
    it "renames the consequent artist back to the antecedent name" do
      ta = create(:active_tag_alias,
                  antecedent_name: "art_undo_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "art_undo_con_#{SecureRandom.hex(4)}")
      ta.consequent_tag.update_columns(category: 1)
      create(:artist, name: ta.consequent_name)

      ta.rename_artist_undo

      expect(Artist.find_by(name: ta.antecedent_name)).to be_present
    end

    it "does nothing when the consequent tag is not in the artist category" do
      ta = create(:active_tag_alias,
                  antecedent_name: "gen_undo_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "gen_undo_con_#{SecureRandom.hex(4)}")
      ta.consequent_tag.update_columns(category: Tag.categories.general)
      create(:artist, name: ta.consequent_name)

      expect { ta.rename_artist_undo }.not_to(change(Artist, :count))
    end
  end

  # ---------------------------------------------------------------------------
  # #move_aliases_and_implications
  # ---------------------------------------------------------------------------

  describe "#move_aliases_and_implications" do
    it "updates existing aliases whose consequent_name matches the antecedent to point to the new consequent" do
      ta = create(:tag_alias,
                  antecedent_name: "move_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "move_con_#{SecureRandom.hex(4)}")
      other = create(:tag_alias,
                     antecedent_name: "move_x_#{SecureRandom.hex(4)}",
                     consequent_name: ta.antecedent_name)

      ta.move_aliases_and_implications

      expect(other.reload.consequent_name).to eq(ta.consequent_name)
    end

    it "destroys an alias when moving it would make it self-referential" do
      ta = create(:tag_alias,
                  antecedent_name: "sr_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "sr_con_#{SecureRandom.hex(4)}")
      # Create an alias whose antecedent equals ta.consequent_name, so moving would
      # produce consequent_name → consequent_name.
      self_ref = create(:tag_alias,
                        antecedent_name: ta.consequent_name,
                        consequent_name: ta.antecedent_name)
      self_ref.update_columns(status: "deleted")

      ta.move_aliases_and_implications

      expect(TagAlias.exists?(self_ref.id)).to be false
    end

    it "updates implications where the antecedent_name matches" do
      ta = create(:tag_alias,
                  antecedent_name: "imp_move_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "imp_move_con_#{SecureRandom.hex(4)}")
      ti = create(:tag_implication,
                  antecedent_name: ta.antecedent_name,
                  consequent_name: "imp_other_#{SecureRandom.hex(4)}")

      ta.move_aliases_and_implications

      expect(ti.reload.antecedent_name).to eq(ta.consequent_name)
    end

    it "updates implications where the consequent_name matches" do
      ta = create(:tag_alias,
                  antecedent_name: "imp_con_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "imp_con_con_#{SecureRandom.hex(4)}")
      ti = create(:tag_implication,
                  antecedent_name: "imp_other2_#{SecureRandom.hex(4)}",
                  consequent_name: ta.antecedent_name)

      ta.move_aliases_and_implications

      expect(ti.reload.consequent_name).to eq(ta.consequent_name)
    end
  end
end
