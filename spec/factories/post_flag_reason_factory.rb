# frozen_string_literal: true

FactoryBot.define do
  factory(:post_flag_reason) do
    name { "guidelines" }
    reason { "Use this if you don't like the post" }
    text { "We'll delete it." }
    index { 0 }

    factory(:needs_staff_reason_post_flag_reason) do
      name { "needs_staff_reason" }
      needs_staff_reason { true }
      index { 1 }
    end

    factory(:needs_parent_id_post_flag_reason) do
      name { "needs_parent_id" }
      reason { "Duplicate or inferior version of another post" }
      needs_parent_id { true }
      index { 2 }
    end

    factory(:needs_explanation_post_flag_reason) do
      name { "needs_explanation" }
      needs_explanation { true }
      index { 3 }
    end

    factory(:grandfathering_post_flag_reason) do
      name { "grandfathering" }
      needs_explanation { true }
      target_date { Time.zone.local(2015, 1, 1) }
      target_date_kind { "after" }
      target_tag { "-grandfathered_content" }
      index { 4 }
    end
  end
end
