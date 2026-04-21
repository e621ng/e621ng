# frozen_string_literal: true

class AutomodUserCheckJob < ApplicationJob
  queue_as :default

  def perform(user_id, check_username:, check_profile:)
    user = User.find(user_id)
    return if Ticket.active.where(qtype: "user", disp_id: user.id).exists?

    # Build mask for relevant contexts and load matching rules in one DB round-trip
    needed_mask = 0
    needed_mask |= 2 if check_username
    needed_mask |= 4 if check_profile
    return if needed_mask == 0

    rules = AutomodRule.enabled.where("(apply_to & ?) > 0", needed_mask).to_a

    rule = nil

    if check_username
      rule = rules.select(&:usernames?).find { |r| r.match?(user.name) }
    end

    if !rule && check_profile
      texts = [user.profile_about, user.profile_artinfo].select(&:present?).join("\n")
      rule = rules.select(&:profile_text?).find { |r| r.match?(texts) }
    end

    return unless rule

    CurrentUser.as_system do
      Ticket.create!(
        creator_id: User.system.id,
        creator_ip_addr: "127.0.0.1",
        disp_id: user.id,
        status: "pending",
        qtype: "user",
        reason: "AutoMod: #{rule.name} \n#{rule.description}",
      )
    end
  rescue ActiveRecord::RecordNotFound
    # User deleted before job ran; nothing to do.
  end
end
