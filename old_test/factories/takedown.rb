# frozen_string_literal: true

FactoryBot.define do
  factory(:takedown) do
    creator_ip_addr { "127.0.0.1" }
    email { "dummy@example.com" }
    source { "example.com" }
    reason { "foo" }
    instructions { "bar" }
  end
end
