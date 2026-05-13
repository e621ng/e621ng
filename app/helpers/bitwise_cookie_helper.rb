# frozen_string_literal: true

module BitwiseCookieHelper
  INDEX = {
    hide_search_trends: 1,
    post_mobile_tab_state: 2,
    hide_post_recommendations: 3,
    hide_wiki_excerpt: 4,
  }.freeze

  # e6_prefs is a base2 cookie where each bit represents a different boolean preference.
  # Up to 31 preferences can be stored in a single cookie - excluding the sign bit.
  COOKIE_NAME = :e6_prefs

  def fetch_raw_bit_cookie
    (cookies[COOKIE_NAME] || "0").to_i(2)
  end

  def fetch_bit_cookie(index)
    (fetch_raw_bit_cookie & (1 << index)) != 0
  end

  def put_bit_cookie(index, bit_value)
    raw_value = fetch_raw_bit_cookie
    if bit_value
      raw_value |= (1 << index)
    else
      raw_value &= ~(1 << index)
    end
    cookies[COOKIE_NAME] = { value: raw_value.to_s(2), expires: 1.year.from_now, httponly: true, same_site: :lax, secure: Rails.env.production? }
  end
end
