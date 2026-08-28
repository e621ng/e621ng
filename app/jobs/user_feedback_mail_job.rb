# frozen_string_literal: true

class UserFeedbackMailJob < ApplicationJob
  sidekiq_options queue: "low_prio"

  def perform(user_id, feedback_id)
    user = User.find(user_id)
    feedback = UserFeedback.find(feedback_id)
    Maintenance::User::UserFeedbackMailer.feedback_notice(user, feedback).deliver_now
  rescue ActiveRecord::RecordNotFound
    # User or feedback deleted before the job ran; nothing to send.
  end
end
