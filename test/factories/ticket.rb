# frozen_string_literal: true

FactoryBot.define do
  factory(:ticket) do
    initialize_with { new(qtype: qtype) }

    transient do
      content { nil }
    end

    qtype { "" }
    reason { "test" }
    creator
    creator_ip_addr { "127.0.0.1" }

    after :build do |ticket, options|
      ticket.disp_id = options.content.id
    end
  end
end
