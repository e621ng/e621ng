class UserFeedbackAddUpdaterId < ActiveRecord::Migration[7.0]
  def change
    add_column :user_feedback, :updater_id, :integer
    add_foreign_key :user_feedback, :users, column: :updater_id
  end
end
