# frozen_string_literal: true

class AddIndexesOnUsersBitPrefs < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    # ==============================================================================================#
    # Only two bit flags have corresponding indexes as of right now.                                #
    # Their positions are hardcoded to make the migration reproducible.                             #
    # * can_approve_posts  index == 15                                                              #
    # * can_upload_free    index == 16                                                              #
    # ==============================================================================================#

    # Build integer bit masks
    cap_mask = (1 << 15)
    cuf_mask = (1 << 16)
    both_mask = cap_mask | cuf_mask

    # Create partial indexes matching the exact predicates used by search.
    # Only the TRUE variants are needed, as they typically include far fewer rows.

    add_index :users, :id,
              name: :index_users_on_bitprefs_cap,
              where: "(bit_prefs & #{cap_mask}) = #{cap_mask}",
              algorithm: :concurrently

    add_index :users, :id,
              name: :index_users_on_bitprefs_cuf,
              where: "(bit_prefs & #{cuf_mask}) = #{cuf_mask}",
              algorithm: :concurrently

    add_index :users, :id,
              name: :index_users_on_bitprefs_both,
              where: "(bit_prefs & #{both_mask}) = #{both_mask}",
              algorithm: :concurrently
  end

  def down
    remove_index :users, name: :index_users_on_bitprefs_cap,  algorithm: :concurrently, if_exists: true
    remove_index :users, name: :index_users_on_bitprefs_cuf,  algorithm: :concurrently, if_exists: true
    remove_index :users, name: :index_users_on_bitprefs_both, algorithm: :concurrently, if_exists: true
  end
end
