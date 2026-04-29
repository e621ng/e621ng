# frozen_string_literal: true

FactoryBot.define do
  factory(:post_flag) do
    post
    reason_name { "dnp_artist" }
    is_resolved { false }
  end
end
