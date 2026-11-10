class AddUpdatedAtIndexToUserFeedback < ActiveRecord::Migration[8.1]
  def change
    UserFeedback.without_timeout do
      add_index(:user_feedback, :updated_at)
    end
  end
end
