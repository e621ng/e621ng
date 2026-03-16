# frozen_string_literal: true

class CreateAwards < ActiveRecord::Migration[7.2]
  def change
    AwardType.without_timeout do
      create_table :award_types do |t|
        t.string :name, null: false
        t.text :description
        t.boolean :has_icon, null: false, default: false
        t.references :creator, foreign_key: { to_table: :users }, null: false

        t.timestamps
      end

      add_index :award_types, :name, unique: true
    end

    Award.without_timeout do
      create_table :awards do |t|
        t.references :award_type, foreign_key: true, null: false
        t.references :user, foreign_key: true, null: false
        t.references :creator, foreign_key: { to_table: :users }, null: false
        t.text :reason

        t.timestamps
      end

      add_index :awards, %i[award_type_id user_id], unique: true
    end
  end
end
