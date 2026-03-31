# frozen_string_literal: true

class AutomodCheckJob < ApplicationJob
  queue_as :default

  def perform(comment_id)
    comment = Comment.find(comment_id)
    return if Ticket.active.where(qtype: "comment", disp_id: comment.id).exists?

    rule = AutomodRule.enabled.find { |r| r.match?(comment.body) }
    return unless rule

    CurrentUser.as_system do
      Ticket.create!(
        creator_id: User.system.id,
        creator_ip_addr: "127.0.0.1",
        disp_id: comment.id,
        status: "pending",
        qtype: "comment",
        reason: "AutoMod: #{rule.name} \n#{rule.description}",
      )
    end
  rescue ActiveRecord::RecordNotFound
    # Comment was deleted before the job ran; nothing to do.
  end
end
