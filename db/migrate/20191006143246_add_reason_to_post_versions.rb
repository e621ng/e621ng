class AddReasonToPostVersions < ActiveRecord::Migration[6.0]
  def change
    add_column :post_versions, :reason, :string
  end
end
