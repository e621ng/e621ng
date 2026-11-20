# frozen_string_literal: true

module Populate
  # Reports random local content, then claims or handles a share of the tickets
  # as a moderator. Types with no local content are skipped.
  class Tickets < Base
    SOURCES = {
      "blip"        => -> { Blip.all },
      "comment"     => -> { Comment.all },
      "dmail"       => -> { Dmail.where("owner_id = to_id") }, # the recipient's copy
      "forum"       => -> { ForumPost.all },
      "pool"        => -> { Pool.all },
      "post"        => -> { Post.all },
      "replacement" => -> { PostReplacement.all },
      "set"         => -> { PostSet.all },
      "user"        => -> { User.where.not(id: User.system.id) },
      "wiki"        => -> { WikiPage.all },
    }.freeze

    REASONS = [
      "Harassment",
      "Spam, they keep posting the same thing over and over.",
      "This is advertising a commission scam.",
      "Trolling and arguing in bad faith.",
      "Personal attack against another user.",
      "Off-topic and inflammatory.",
      "Vandalism",
      "Ban evasion, this is the same person as before.",
      "Roleplaying in the comments.",
      "Posting personal information.",
    ].freeze

    RESPONSES = [
      "Handled, thank you.",
      "Thank you for the report. The user has been given a record.",
      "Reviewed, no rule violation found.",
      "Already dealt with in another ticket.",
      "Removed.",
      "We need more information to act on this. Please reply with links.",
    ].freeze

    # Share of tickets left pending and unclaimed, claimed, partially handled; the rest are approved.
    UNCLAIMED = 0.45
    CLAIMED = 0.10
    PARTIAL = 0.10

    def call
      count = options.fetch(:count, 0)
      return [] unless count > 0
      log "* Creating #{count} tickets"

      @users = options.fetch(:users, []).to_a
      @users = random_users.to_a if @users.empty?
      @users = @users.reject(&:is_system?)
      @moderators = User.where(level: UserLevel::MODERATOR..).order("random()").limit(distribution).to_a
      @report_reasons = PostReportReason.all.to_a

      contents = load_contents
      if contents.empty? || @users.empty?
        log "  nothing to report: no eligible users or content"
        return []
      end
      log "  types: #{contents.keys.join(', ')}"

      output = []
      (count * 5).times do
        break if output.size >= count
        qtype = contents.keys.sample
        ticket = create_ticket(qtype, contents[qtype].sample)
        next if ticket.nil?

        handle(ticket)
        log "  - ##{ticket.id} #{qtype} ##{ticket.disp_id} by #{ticket.creator.name} (#{status_label(ticket)})"
        output << ticket
      end

      log "  only #{output.size} of #{count} created" if output.size < count
      output
    end

    private

    def load_contents
      types = options.fetch(:types, [])
      unknown = types - SOURCES.keys
      raise ArgumentError, "unknown ticket types: #{unknown.join(', ')} (known: #{SOURCES.keys.join(', ')})" if unknown.any?

      sources = types.empty? ? SOURCES : SOURCES.slice(*types)
      sources = sources.except("post") if @report_reasons.empty?
      sources.transform_values { |scope| scope.call.order("random()").limit(50).to_a }.reject { |_, records| records.empty? }
    end

    def create_ticket(qtype, content)
      reporter = qtype == "dmail" ? content.to : @users.sample
      return nil if accused_id(qtype, content) == reporter.id
      return nil if Ticket.where(creator_id: reporter.id, qtype: qtype, disp_id: content.id).exists?

      CurrentUser.user = reporter
      ticket = Ticket.new(qtype: qtype, disp_id: content.id, reason: reason)
      ticket.report_reason = @report_reasons.sample.id.to_s if qtype == "post"
      return nil unless ticket.can_create_for?(reporter)

      unless ticket.save
        log "    error: #{ticket.errors.full_messages.join('; ')}"
        return nil
      end
      ticket
    end

    def accused_id(qtype, content)
      case qtype
      when "user" then content.id
      when "dmail" then content.from_id
      when "post" then content.uploader_id
      else content.try(:creator_id)
      end
    end

    def reason
      text = REASONS.sample
      text += "\n\n#{Faker::Hipster.paragraph_by_chars(characters: rand(50..400), supplemental: false)}" if Faker::Boolean.boolean(true_ratio: 0.4)
      text
    end

    # The same steps as TicketsController#claim and #update, so the mod actions
    # and the notification dmail to the reporter exist too.
    def handle(ticket)
      roll = rand
      return if roll < UNCLAIMED
      moderator = @moderators.reject { |user| user.id == ticket.creator_id }.sample
      return if moderator.nil?

      CurrentUser.user = moderator
      if roll < UNCLAIMED + CLAIMED
        ticket.claim!(moderator)
      else
        ticket.update(
          handler_id: moderator.id,
          claimant_id: moderator.id,
          status: roll < UNCLAIMED + CLAIMED + PARTIAL ? "partial" : "approved",
          response: RESPONSES.sample,
        )
        log "    error: #{ticket.errors.full_messages.join('; ')}" unless ticket.valid?
      end
    end

    def status_label(ticket)
      ticket.pending? && ticket.claimant_id ? "claimed" : ticket.status
    end
  end
end
