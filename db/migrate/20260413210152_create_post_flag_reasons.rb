# frozen_string_literal: true

class CreatePostFlagReasons < ActiveRecord::Migration[6.1]
  def change
    create_table :post_flag_reasons do |t|
      t.string :name, null: false
      t.string :reason, null: false
      t.text :text, null: false, default: ""

      t.boolean :needs_explanation, null: false, default: false
      t.boolean :needs_parent_id, null: false, default: false
      t.boolean :needs_staff_reason, null: false, default: false

      t.integer :index, null: false, default: 0

      t.date :target_date, null: true
      t.string :target_date_kind, null: true
      t.string :target_tag, null: true

      t.timestamps
    end

    add_index :post_flag_reasons, :name, unique: true
    add_index :post_flag_reasons, :index

    PostFlag.without_timeout do
      # It's impossible to recover the reason names for sure, but "inferior" is the only one
      # that's really needed, and the harcoded logic already used this regex match to identify it.
      add_column :post_flags, :reason_name, :string, null: true
      add_column :post_flags, :needs_parent_id, :boolean, null: false, default: false
      PostFlag.where("reason ~* ?", "Inferior").update_all(reason_name: "inferior", needs_parent_id: true)
      # Similar thing here, there was hardcoded logic around regex matching uploading_guidelines
      # and requiring staff to give their own deletion reason.
      add_column :post_flags, :needs_staff_reason, :boolean, null: false, default: false
      PostFlag.where("reason ~ ?", "uploading_guidelines").update_all(reason_name: "uploading_guidelines", needs_staff_reason: true)
    end
  end
end
