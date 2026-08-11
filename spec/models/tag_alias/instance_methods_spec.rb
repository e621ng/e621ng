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
    it "always creates a side effects record, even with no affected posts" do
      ta = create(:tag_alias)

      expect { ta.create_undo_information }.to change(TagRelUndo, :count).by(1)

      side_effects = ta.tag_rel_undos.find(&:side_effects?)
      expect(side_effects.undo_data["alias"]).to eq("antecedent_name" => ta.antecedent_name, "consequent_name" => ta.consequent_name)
    end

    it "records the consequent as added for posts that lacked it and nothing for posts that had it" do
      ta = create(:tag_alias,
                  antecedent_name: "undo_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "undo_con_#{SecureRandom.hex(4)}")
      with_post = create(:post, tag_string: "#{ta.antecedent_name} #{ta.consequent_name}")
      without_post = create(:post, tag_string: "#{ta.antecedent_name} other_tag")

      ta.create_undo_information

      added = ta.tag_rel_undos.find(&:posts_chunk?).undo_data["added"]
      expect(added.keys).to contain_exactly(with_post.id.to_s, without_post.id.to_s)
      expect(added[with_post.id.to_s]).to eq([])
      expect(added[without_post.id.to_s]).to eq([ta.consequent_name])
    end

    it "includes the consequent's active implication chain in the added set" do
      ta = create(:tag_alias,
                  antecedent_name: "chain_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "chain_con_#{SecureRandom.hex(4)}")
      b = "chain_b_#{SecureRandom.hex(4)}"
      d = "chain_d_#{SecureRandom.hex(4)}"
      create(:active_tag_implication, antecedent_name: ta.consequent_name, consequent_name: b)
      create(:active_tag_implication, antecedent_name: b, consequent_name: d)
      create(:tag_implication, antecedent_name: d, consequent_name: "chain_pending_#{SecureRandom.hex(4)}")
      post = create(:post, tag_string: "#{ta.antecedent_name} other_tag")

      ta.create_undo_information

      added = ta.tag_rel_undos.find(&:posts_chunk?).undo_data["added"]
      expect(added[post.id.to_s]).to contain_exactly(ta.consequent_name, b, d)
    end

    it "excludes implied tags the post already carries from the added set" do
      ta = create(:tag_alias,
                  antecedent_name: "have_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "have_con_#{SecureRandom.hex(4)}")
      b = "have_b_#{SecureRandom.hex(4)}"
      create(:active_tag_implication, antecedent_name: ta.consequent_name, consequent_name: b)
      post = create(:post, tag_string: "#{ta.antecedent_name} #{b}")

      ta.create_undo_information

      added = ta.tag_rel_undos.find(&:posts_chunk?).undo_data["added"]
      expect(added[post.id.to_s]).to eq([ta.consequent_name])
    end

    it "treats the antecedent's active implications as already moved onto the consequent" do
      ta = create(:tag_alias,
                  antecedent_name: "moved_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "moved_con_#{SecureRandom.hex(4)}")
      x = "moved_x_#{SecureRandom.hex(4)}"
      # Created after the post so the post doesn't pick it up on save; by the
      # time update_posts runs, move_aliases_and_implications will have
      # rewritten it onto the consequent.
      post = create(:post, tag_string: "#{ta.antecedent_name} other_tag")
      create(:active_tag_implication, antecedent_name: ta.antecedent_name, consequent_name: x)

      ta.create_undo_information

      added = ta.tag_rel_undos.find(&:posts_chunk?).undo_data["added"]
      expect(added[post.id.to_s]).to contain_exactly(ta.consequent_name, x)
    end

    it "records the relationships that will be moved" do
      ta = create(:tag_alias,
                  antecedent_name: "rel_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "rel_con_#{SecureRandom.hex(4)}")
      other = create(:tag_alias,
                     antecedent_name: "rel_x_#{SecureRandom.hex(4)}",
                     consequent_name: ta.antecedent_name)
      ti = create(:tag_implication,
                  antecedent_name: ta.antecedent_name,
                  consequent_name: "rel_y_#{SecureRandom.hex(4)}")

      ta.create_undo_information

      relationships = ta.tag_rel_undos.find(&:side_effects?).undo_data["relationships"]
      expect(relationships).to contain_exactly(
        a_hash_including("class" => "TagAlias", "id" => other.id, "antecedent_name" => other.antecedent_name, "consequent_name" => other.consequent_name),
        a_hash_including("class" => "TagImplication", "id" => ti.id, "antecedent_name" => ti.antecedent_name, "consequent_name" => ti.consequent_name),
      )
    end

    it "records the category change when one will occur" do
      ta = create(:tag_alias,
                  antecedent_name: "cat_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "cat_con_#{SecureRandom.hex(4)}")
      ta.antecedent_tag.update_columns(category: 1)
      ta.consequent_tag.update_columns(category: Tag.categories.general)

      ta.create_undo_information

      category_change = ta.tag_rel_undos.find(&:side_effects?).undo_data["category_change"]
      expect(category_change).to eq("tag_name" => ta.consequent_name, "old_category" => Tag.categories.general, "new_category" => 1)
    end

    it "keeps a complete snapshot from a failed previous process! attempt instead of rebuilding it" do
      ta = create(:tag_alias,
                  antecedent_name: "retry_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "retry_con_#{SecureRandom.hex(4)}")
      ta.create_undo_information
      original_row_ids = ta.tag_rel_undos.pluck(:id)

      expect { ta.create_undo_information }.not_to change(TagRelUndo, :count)
      expect(ta.tag_rel_undos.pluck(:id)).to eq(original_row_ids)
    end

    it "rebuilds an incomplete snapshot from a failed previous process! attempt" do
      ta = create(:tag_alias,
                  antecedent_name: "retry2_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "retry2_con_#{SecureRandom.hex(4)}")
      # A posts chunk without the side effects record means the previous
      # snapshot attempt died partway through.
      stale = ta.tag_rel_undos.create!(undo_data: { "version" => 3, "kind" => "posts", "added" => { "999" => [ta.consequent_name] } })

      ta.create_undo_information

      expect(TagRelUndo.exists?(stale.id)).to be false
      expect(ta.tag_rel_undos.reload.find(&:side_effects?)).to be_present
    end

    it "records the artist rename when one will occur" do
      ta = create(:tag_alias,
                  antecedent_name: "cua_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "cua_con_#{SecureRandom.hex(4)}")
      ta.antecedent_tag.update_columns(category: 1)
      artist = create(:artist, name: ta.antecedent_name)

      ta.create_undo_information

      artist_change = ta.tag_rel_undos.find(&:side_effects?).undo_data["artist_change"]
      expect(artist_change).to eq("action" => "rename", "artist_id" => artist.id, "old_name" => ta.antecedent_name, "new_name" => ta.consequent_name)
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
  # #update_posts_undo
  # ---------------------------------------------------------------------------

  describe "#update_posts_undo" do
    def create_pending_undoable_alias
      ta = create(:active_tag_alias,
                  antecedent_name: "undo_post_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "undo_post_con_#{SecureRandom.hex(4)}")
      # Set to pending so normalize_tags doesn't re-alias the antecedent back to the
      # consequent during the post save (mirrors what process_undo! does before calling this).
      ta.update_columns(status: "pending")
      ta
    end

    def create_posts_chunk(rel, added: {})
      rel.tag_rel_undos.create!(undo_data: {
        "version" => 3,
        "kind" => "posts",
        "added" => added,
      })
    end

    it "restores the antecedent and removes the consequent from posts that gained it from the alias" do
      ta = create_pending_undoable_alias
      post = create(:post, tag_string: "#{ta.consequent_name} other_tag")
      create_posts_chunk(ta, added: { post.id.to_s => [ta.consequent_name] })

      ta.update_posts_undo

      expect(post.reload.tag_string.split).to include(ta.antecedent_name)
      expect(post.reload.tag_string.split).not_to include(ta.consequent_name)
    end

    it "restores the antecedent but keeps the consequent on posts that had it before the alias" do
      ta = create_pending_undoable_alias
      post = create(:post, tag_string: "#{ta.consequent_name} other_tag")
      create_posts_chunk(ta, added: { post.id.to_s => [] })

      ta.update_posts_undo

      expect(post.reload.tag_string.split).to include(ta.antecedent_name, ta.consequent_name)
    end

    it "removes tags the alias pulled in through implications" do
      ta = create_pending_undoable_alias
      b = "undo_imp_#{SecureRandom.hex(4)}"
      post = create(:post, tag_string: "#{ta.consequent_name} #{b} other_tag")
      create_posts_chunk(ta, added: { post.id.to_s => [ta.consequent_name, b] })

      ta.update_posts_undo

      expect(post.reload.tag_string.split).to include(ta.antecedent_name, "other_tag")
      expect(post.reload.tag_string.split).not_to include(ta.consequent_name, b)
    end

    it "keeps a recorded tag that another tag on the post still implies" do
      ta = create_pending_undoable_alias
      b = "undo_keep_#{SecureRandom.hex(4)}"
      other_src = "undo_src_#{SecureRandom.hex(4)}"
      create(:active_tag_implication, antecedent_name: other_src, consequent_name: b)
      post = create(:post, tag_string: "#{ta.consequent_name} #{other_src}")
      create_posts_chunk(ta, added: { post.id.to_s => [ta.consequent_name, b] })

      ta.update_posts_undo

      expect(post.reload.tag_string.split).to include(ta.antecedent_name, other_src, b)
      expect(post.reload.tag_string.split).not_to include(ta.consequent_name)
    end

    it "ignores recorded tags the post no longer carries" do
      ta = create_pending_undoable_alias
      post = create(:post, tag_string: "#{ta.consequent_name} other_tag")
      create_posts_chunk(ta, added: { post.id.to_s => [ta.consequent_name, "undo_gone_#{SecureRandom.hex(4)}"] })

      ta.update_posts_undo

      expect(post.reload.tag_string.split).to include(ta.antecedent_name, "other_tag")
      expect(post.reload.tag_string.split).not_to include(ta.consequent_name)
    end

    it "leaves posts alone when the consequent tag was removed since the alias was processed" do
      ta = create_pending_undoable_alias
      post = create(:post, tag_string: "other_tag")
      create_posts_chunk(ta, added: { post.id.to_s => [ta.consequent_name] })

      original_tag_string = post.reload.tag_string
      ta.update_posts_undo

      expect(post.reload.tag_string).to eq(original_tag_string)
    end

    it "marks processed chunks as applied" do
      ta = create_pending_undoable_alias
      chunk = create_posts_chunk(ta)

      ta.update_posts_undo

      expect(chunk.reload.applied).to be true
    end

    it "enqueues TagAliasFinalizeJob" do
      ta = create_pending_undoable_alias
      create_posts_chunk(ta)

      expect { ta.update_posts_undo }
        .to have_enqueued_job(TagAliasFinalizeJob).with(ta.id)
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
  # #restore_relationships_undo
  # ---------------------------------------------------------------------------

  describe "#restore_relationships_undo" do
    subject(:ta) do
      ta = create(:active_tag_alias,
                  antecedent_name: "rr_ant_#{SecureRandom.hex(4)}",
                  consequent_name: "rr_con_#{SecureRandom.hex(4)}")
      # Mirrors process_undo!, which resets the status before restoring relationships;
      # while the alias is active, the restored rows would fail their own validations.
      ta.update_columns(status: "pending")
      ta
    end

    it "moves a rewritten alias back to its original names" do
      other = create(:tag_alias,
                     antecedent_name: "rr_x_#{SecureRandom.hex(4)}",
                     consequent_name: ta.antecedent_name)
      data = [ta.serialize_relationship(other)]
      other.update_columns(consequent_name: ta.consequent_name) # simulate the move

      ta.restore_relationships_undo(data)

      expect(other.reload.consequent_name).to eq(ta.antecedent_name)
    end

    it "moves a rewritten implication back to its original names" do
      ti = create(:tag_implication,
                  antecedent_name: ta.antecedent_name,
                  consequent_name: "rr_y_#{SecureRandom.hex(4)}")
      data = [ta.serialize_relationship(ti)]
      ti.update_columns(antecedent_name: ta.consequent_name) # simulate the move

      ta.restore_relationships_undo(data)

      expect(ti.reload.antecedent_name).to eq(ta.antecedent_name)
    end

    it "recreates a relationship that was destroyed for becoming self-referential" do
      self_ref = create(:tag_alias,
                        antecedent_name: ta.consequent_name,
                        consequent_name: ta.antecedent_name)
      self_ref.update_columns(status: "deleted")
      data = [ta.serialize_relationship(self_ref)]
      original_creator_id = self_ref.creator_id
      original_creator_ip_addr = self_ref.creator_ip_addr
      self_ref.destroy # simulate the destruction during process!

      ta.restore_relationships_undo(data)

      restored = TagAlias.find_by(antecedent_name: ta.consequent_name, consequent_name: ta.antecedent_name)
      expect(restored).to be_present
      expect(restored.status).to eq("deleted")
      expect(restored.creator_id).to eq(original_creator_id)
      expect(restored.creator_ip_addr).to eq(original_creator_ip_addr)
    end

    it "does not recreate a relationship that was deleted for reasons other than becoming self-referential" do
      other = create(:tag_alias,
                     antecedent_name: "rr_del_#{SecureRandom.hex(4)}",
                     consequent_name: ta.antecedent_name)
      data = [ta.serialize_relationship(other)]
      other.update_columns(consequent_name: ta.consequent_name) # simulate the move
      other.destroy # deleted by an admin afterwards

      expect { ta.restore_relationships_undo(data) }.not_to change(TagAlias, :count)
    end

    it "skips relationships that were modified since the alias was processed" do
      other = create(:tag_alias,
                     antecedent_name: "rr_z_#{SecureRandom.hex(4)}",
                     consequent_name: ta.antecedent_name)
      data = [ta.serialize_relationship(other)]
      other.update_columns(consequent_name: "rr_manual_#{SecureRandom.hex(4)}") # edited by hand, not by the move

      ta.restore_relationships_undo(data)

      expect(other.reload.consequent_name).not_to eq(ta.antecedent_name)
    end
  end

  # ---------------------------------------------------------------------------
  # #restore_category_undo
  # ---------------------------------------------------------------------------

  describe "#restore_category_undo" do
    subject(:ta) do
      create(:active_tag_alias,
             antecedent_name: "rc_ant_#{SecureRandom.hex(4)}",
             consequent_name: "rc_con_#{SecureRandom.hex(4)}")
    end

    it "reverts the consequent tag category" do
      ta.consequent_tag.update_columns(category: 1)

      ta.restore_category_undo("tag_name" => ta.consequent_name, "old_category" => 0, "new_category" => 1)

      expect(ta.consequent_tag.reload.category).to eq(0)
    end

    it "does nothing when the category was changed again since the alias was processed" do
      ta.consequent_tag.update_columns(category: 3)

      ta.restore_category_undo("tag_name" => ta.consequent_name, "old_category" => 0, "new_category" => 1)

      expect(ta.consequent_tag.reload.category).to eq(3)
    end

    it "does nothing when no category change was recorded" do
      expect { ta.restore_category_undo(nil) }.not_to(change { ta.consequent_tag.reload.category })
    end
  end

  # ---------------------------------------------------------------------------
  # #restore_artist_undo
  # ---------------------------------------------------------------------------

  describe "#restore_artist_undo" do
    subject(:ta) do
      create(:active_tag_alias,
             antecedent_name: "ra_ant_#{SecureRandom.hex(4)}",
             consequent_name: "ra_con_#{SecureRandom.hex(4)}")
    end

    it "renames the artist back to the antecedent name" do
      artist = create(:artist, name: ta.consequent_name)

      ta.restore_artist_undo("action" => "rename", "artist_id" => artist.id, "old_name" => ta.antecedent_name, "new_name" => ta.consequent_name)

      expect(artist.reload.name).to eq(ta.antecedent_name)
    end

    it "does not rename when the artist was renamed again since" do
      artist = create(:artist, name: "ra_other_#{SecureRandom.hex(4)}")

      ta.restore_artist_undo("action" => "rename", "artist_id" => artist.id, "old_name" => ta.antecedent_name, "new_name" => ta.consequent_name)

      expect(artist.reload.name).not_to eq(ta.antecedent_name)
    end

    it "does not rename when another artist now uses the original name" do
      artist = create(:artist, name: ta.consequent_name)
      create(:artist, name: ta.antecedent_name)

      ta.restore_artist_undo("action" => "rename", "artist_id" => artist.id, "old_name" => ta.antecedent_name, "new_name" => ta.consequent_name)

      expect(artist.reload.name).to eq(ta.consequent_name)
    end

    it "transfers the linked user back to the antecedent artist" do
      linked_user = create(:user)
      ant_artist = create(:artist, name: ta.antecedent_name)
      con_artist = create(:artist, name: ta.consequent_name, linked_user_id: linked_user.id)

      ta.restore_artist_undo(
        "action" => "transfer_linked_user",
        "antecedent_artist_id" => ant_artist.id,
        "consequent_artist_id" => con_artist.id,
        "linked_user_id" => linked_user.id,
      )

      expect(ant_artist.reload.linked_user_id).to eq(linked_user.id)
      expect(con_artist.reload.linked_user_id).to be_nil
    end

    it "does not transfer when the linked user was changed since" do
      ant_artist = create(:artist, name: ta.antecedent_name)
      con_artist = create(:artist, name: ta.consequent_name, linked_user_id: create(:user).id)

      ta.restore_artist_undo(
        "action" => "transfer_linked_user",
        "antecedent_artist_id" => ant_artist.id,
        "consequent_artist_id" => con_artist.id,
        "linked_user_id" => create(:user).id,
      )

      expect(ant_artist.reload.linked_user_id).to be_nil
      expect(con_artist.reload.linked_user_id).not_to be_nil
    end

    it "does nothing when no artist change was recorded" do
      expect { ta.restore_artist_undo(nil) }.not_to raise_error
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
