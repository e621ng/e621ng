# frozen_string_literal: true

class AddIndexPoolsOnPostIds < ActiveRecord::Migration[8.0]
  def change
    Pool.without_timeout do
      add_index :pools, :post_ids, using: :gin
    end
  end
end
