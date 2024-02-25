# frozen_string_literal: true

class DummyTicket
  def initialize(accused, post_id)
    @ticket = Ticket.new(
      id: 0,
      created_at: Time.now,
      updated_at: Time.now,
      creator_id: User.system.id,
      disp_id: 0,
      status: "pending",
      qtype: "user",
      reason: "User ##{accused.id} (#{accused.name}) tried to reupload destroyed post ##{post_id}",
    )
  end

  def notify
    @ticket.push_pubsub("create")
  end
end
