# frozen_string_literal: true

class AddHotnessToPosts < ActiveRecord::Migration[8.1]
  def change
    # Stored as double precision (Rails :float)
    # The created_at term is ~4,000 in magnitude and must not swamp sub-0.001 same-day
    # differences in log10(score).
    add_column :posts, :hotness, :float, null: false, default: 0.0
  end
end
