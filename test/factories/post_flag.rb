# frozen_string_literal: true

FactoryBot.define do
  factory(:post_flag) do
    post
    reason_name { association(:post_flag_reason).name }
    is_resolved { false }
  end
end
