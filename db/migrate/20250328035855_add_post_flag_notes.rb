# frozen_string_literal: true

class AddPostFlagNotes < ActiveRecord::Migration[7.1]
  def change
    PostFlag.without_timeout do
      add_column :post_flags, :note, :string
    end
  end
end
