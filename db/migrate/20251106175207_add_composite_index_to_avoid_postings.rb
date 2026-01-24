# frozen_string_literal: true

class AddCompositeIndexToAvoidPostings < ActiveRecord::Migration[7.2]
  def change
    add_index :avoid_postings, %i[is_active id], name: "index_avoid_postings_on_is_active_and_id"
  end
end
