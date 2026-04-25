# frozen_string_literal: true

FactoryBot.define do
  factory(:post_flag_reason) do
    name { "dnp_artist" }
    reason { "Artist is on the DNP list" }
    text { "This artist has requested their art not be posted to the site." }
    index { 0 }

    factory(:post_flag_reason_with_grandfathering) do
      name { "uploading_guidelines" }
      reason { "Use this if you don't like the post" }
      text { "We'll delete it." }
      needs_explanation { true }
      target_date { Time.zone.local(2015, 1, 1) }
      target_date_kind { "after" }
      target_tag { "-grandfathered_content" }
      index { 1 }
    end
  end
end
