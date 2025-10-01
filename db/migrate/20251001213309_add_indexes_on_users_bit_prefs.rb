# frozen_string_literal: true

class AddIndexesOnUsersBitPrefs < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    # Only two flags are currently used in bit_prefs filters in searches:
    # :can_approve_posts and :can_upload_free
    #
    # IMPORTANT: We hardcode positions to make this migration reproducible
    # even if the application constants change later.
    # As of this migration:
    # - can_approve_posts index == 15
    # - can_upload_free  index == 16
    cap_idx = 15
    cuf_idx = 16

    # Build integer bit masks matching how flags are stored in bigint bit_prefs.
    cap_mask = (1 << cap_idx)
    cuf_mask = (1 << cuf_idx)

    both_mask = cap_mask | cuf_mask

    # Create partial indexes matching the exact predicates used by search.
    # TRUE (include) variants — these are highly selective and useful
    add_index :users, :id,
              name: :index_users_on_cap_include,
              where: "(bit_prefs & #{cap_mask}) = #{cap_mask}",
              algorithm: :concurrently

    add_index :users, :id,
              name: :index_users_on_cuf_include,
              where: "(bit_prefs & #{cuf_mask}) = #{cuf_mask}",
              algorithm: :concurrently

    add_index :users, :id,
              name: :index_users_on_both_include,
              where: "(bit_prefs & #{both_mask}) = #{both_mask}",
              algorithm: :concurrently
  end

  def down
    remove_index :users, name: :index_users_on_both_include, algorithm: :concurrently, if_exists: true
    remove_index :users, name: :index_users_on_cuf_include,  algorithm: :concurrently, if_exists: true
    remove_index :users, name: :index_users_on_cap_include,  algorithm: :concurrently, if_exists: true
  end
end
