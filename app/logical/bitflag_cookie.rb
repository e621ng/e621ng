# frozen_string_literal: true

class BitflagCookie
  INDEX = {
    hide_search_trends: 1,
    post_mobile_tab_state: 2,
    hide_post_recommendations: 3,
    hide_wiki_excerpt: 4,
  }.freeze

  # e6_prefs is a base2 cookie where each bit represents a different boolean preference.
  # Up to 31 preferences can be stored in a single cookie - excluding the sign bit.
  COOKIE_NAME = :e6_prefs

  def initialize(cookies)
    @cookies = cookies
  end

  def read(name)
    index = INDEX[name]
    return false unless index

    (raw & (1 << index)) != 0
  end

  def write(name, value)
    index = INDEX[name]
    return unless index

    raw_value = raw
    raw_value = value ? raw_value | (1 << index) : raw_value & ~(1 << index)
    @cookies[COOKIE_NAME] = { value: raw_value.to_s(2), expires: 1.year.from_now, httponly: true, same_site: :lax, secure: Rails.env.production? }
  end

  private

  def raw
    (@cookies[COOKIE_NAME] || "0").to_i(2)
  end
end
