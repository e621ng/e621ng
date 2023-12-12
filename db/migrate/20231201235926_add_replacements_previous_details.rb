class AddReplacementsPreviousDetails < ActiveRecord::Migration[7.0]
  def change
    add_column :post_replacements2, :previous_details, :jsonb
  end
end
