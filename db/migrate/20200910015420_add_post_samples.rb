class AddPostSamples < ActiveRecord::Migration[6.0]
  def change
    add_column :posts, :generated_samples, :string, array: true, nil: true
  end
end
