# frozen_string_literal: true

module Populate
  class Dmails < Base
    def call
      count = options.fetch(:count, 0)
      return unless count > 0
      log "* Generating DMs"

      users = random_users(limit: 100).to_a

      count.times do
        sender = users.sample
        recipient = users.sample
        next if sender == recipient

        dmail = Dmail.create_split(
          from_id: sender.id,
          to_id: recipient.id,
          title: Faker::Hipster.sentence(word_count: rand(3..10)),
          body: paragraph,
          bypass_limits: true,
        )

        log "  - DM ##{dmail.id} from #{sender.name} to #{recipient.name}"
        log "    #{dmail.errors.full_messages.join('; ')}" unless dmail.valid?
      end
    end
  end
end
