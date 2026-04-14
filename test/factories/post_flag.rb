# frozen_string_literal: true

FactoryBot.define do
  factory(:post_flag) do
    post
    reason_name { "dnp_director" }
    is_resolved { false }
  end
end
