# frozen_string_literal: true

class PostVersionAddHidden < ActiveRecord::Migration[7.1]
  def change
    PostVersion.without_timeout do
      add_column :post_versions, :is_hidden, :boolean, default: false, null: false
    end
  end
end
